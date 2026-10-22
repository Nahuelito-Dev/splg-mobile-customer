#!/usr/bin/env python3
"""Capturas de los CU Reales de la app cliente, con la app corriendo contra el back.

Corre `integration_test/capturas_cu_reales_test.dart` en el simulador y saca una
captura (`xcrun simctl io <udid> screenshot`) cada vez que el test imprime
`SHOT:<nombre>`. Cuando imprime `READY:en-camino` prepara por la API el pedido
«Prueba capturas …» en camino (lo asigna al chofer de la demo y le pone posición)
y, al terminar, lo cancela.

    scripts/capturas_cu_reales.py [--udid UDID] [--api http://localhost:3010]

Las capturas quedan en `build/capturas_cu_reales/<nombre>.png`. Requiere el back
y la base de desarrollo levantados (`../splg-dev.sh`) y la cuenta cliente@splg.com.
Efectos sobre la base: un pedido «Prueba capturas …» que el test crea y cancela
desde la app y otro que este script crea por la API y cancela al final. Ningún
reclamo se envía y el registro de CU-002 queda sin enviar (no toca Firebase).
"""
import argparse
import datetime
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
import uuid

UDID = 'C843B2DD-450F-41A2-8125-B92C544543A1'  # iPhone 16 Pro
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, 'build', 'capturas_cu_reales')

CLIENTE = 'cliente@splg.com'
ADMIN = 'admin@splg.com'
CHOFER = 'chofer@splg.com'
CLAVE = 'Test1234'
NOTA = 'Prueba capturas en camino'


class Api:
    def __init__(self, base):
        self.base = base.rstrip('/') + '/api'
        self.tokens = {}

    def call(self, metodo, ruta, cuerpo=None, email=None, fuente='panel-app'):
        headers = {
            'Content-Type': 'application/json',
            'X-Distributor': 'demo',
            'X-Client-Source': fuente,
            'Idempotency-Key': str(uuid.uuid4()),
        }
        if email:
            headers['Authorization'] = 'Bearer ' + self.token(email)
        datos = json.dumps(cuerpo).encode() if cuerpo is not None else None
        req = urllib.request.Request(self.base + ruta, data=datos, headers=headers,
                                     method=metodo)
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                texto = r.read().decode()
                return r.status, json.loads(texto) if texto else None
        except urllib.error.HTTPError as e:
            texto = e.read().decode()
            try:
                return e.code, json.loads(texto)
            except ValueError:
                return e.code, texto

    def token(self, email):
        if email not in self.tokens:
            cuerpo = {'email': email, 'password': CLAVE}
            req = urllib.request.Request(
                self.base + '/auth/login', data=json.dumps(cuerpo).encode(),
                headers={'Content-Type': 'application/json', 'X-Distributor': 'demo',
                         'X-Client-Source': 'panel-app'})
            with urllib.request.urlopen(req, timeout=30) as r:
                self.tokens[email] = json.load(r)['accessToken']
        return self.tokens[email]

    def ok(self, metodo, ruta, cuerpo=None, email=None, fuente='panel-app'):
        estado, datos = self.call(metodo, ruta, cuerpo, email, fuente)
        if estado >= 300:
            raise RuntimeError(f'{metodo} {ruta} -> {estado} {datos}')
        return datos


class Preparacion:
    """Datos que el test no puede armar desde la app."""

    def __init__(self, api):
        self.api = api
        self.pedidos = []

    def pedido_en_camino(self):
        api = self.api
        cliente = api.ok('GET', '/users/email/' + CLIENTE, email=CLIENTE,
                         fuente='customer-app')
        direcciones = api.ok('GET', '/user-address/user/' + cliente['user_id'],
                             email=CLIENTE, fuente='customer-app')
        direccion = next(d for d in direcciones if d.get('isDefault')) \
            if isinstance(direcciones, list) else direcciones['addresses'][0]
        garrafas = api.ok('GET', '/gascylinder', email=CLIENTE,
                          fuente='customer-app')['gasCylinders']
        garrafa = next(g for g in garrafas if g['type'] == 'Garrafa 10kg')
        fecha = (datetime.date.today() + datetime.timedelta(days=2)).isoformat()
        franjas = api.ok('GET', f'/time-slot/availability?date={fecha}',
                         email=CLIENTE, fuente='customer-app')
        pedido = api.ok('POST', '/orders', {
            'customerId': cliente['user_id'],
            'addressId': direccion['address_id'] if 'address_id' in direccion
            else direccion['addressId'],
            'paymentMethod': 'cash',
            'items': [{'gasCylinderId': garrafa['gas_cylinder_id'], 'quantity': 2,
                       'unitPrice': garrafa['price']}],
            'scheduledDate': fecha,
            'timeSlotId': franjas[0]['timeSlotId'],
            'notes': NOTA,
        }, email=CLIENTE, fuente='customer-app')
        oid = pedido['order_id']
        self.pedidos.append(oid)
        choferes = api.ok('GET', '/delivery', email=ADMIN)
        chofer = api.ok('GET', '/users/email/' + CHOFER, email=ADMIN)
        delivery = next(d for d in choferes if d['user_id'] == chofer['user_id'])
        api.ok('PATCH', f'/orders/{oid}/assign/{delivery["delivery_id"]}', {},
               email=ADMIN)
        api.ok('PATCH', f'/orders/{oid}/status', {'status': 'on_the_way'},
               email=ADMIN)
        # El chofer a unas cuadras del domicilio, para que el mapa lo muestre.
        lat = float(direccion.get('latitude') or direccion.get('lat'))
        lng = float(direccion.get('longitude') or direccion.get('lng'))
        api.ok('PATCH', f'/orders/{oid}/location',
               {'lat': str(lat + 0.006), 'lng': str(lng - 0.004)},
               email=CHOFER, fuente='driver-app')
        print(f'[api] pedido en camino {oid}', flush=True)

    def limpiar(self):
        for oid in self.pedidos:
            estado, datos = self.api.call(
                'PATCH', f'/orders/{oid}/status',
                {'status': 'cancelled', 'reason': 'Prueba capturas: se cancela'},
                email=ADMIN)
            print(f'[api] cancelar {oid} -> {estado}', flush=True)


def captura(udid, nombre):
    os.makedirs(SALIDA, exist_ok=True)
    destino = os.path.join(SALIDA, nombre + '.png')
    subprocess.run(['xcrun', 'simctl', 'io', udid, 'screenshot', '--type=png',
                    destino], check=True, capture_output=True)
    print(f'[captura] {destino}', flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--udid', default=UDID)
    ap.add_argument('--api', default='http://localhost:3010')
    args = ap.parse_args()

    prep = Preparacion(Api(args.api))
    # Barra de estado limpia y fija, y sin avisos de permisos que tapen la pantalla.
    subprocess.run(['xcrun', 'simctl', 'status_bar', args.udid, 'override',
                    '--time', '9:41', '--batteryState', 'charged',
                    '--batteryLevel', '100', '--wifiBars', '3', '--cellularBars', '4'],
                   check=False)
    subprocess.run(['xcrun', 'simctl', 'privacy', args.udid, 'grant',
                    'location-always', 'com.nahuelwagner.splg.customer'], check=False)
    cmd = ['flutter', 'test', 'integration_test/capturas_cu_reales_test.dart',
           '-d', args.udid, f'--dart-define=API_BASE_URL={args.api}',
           '--dart-define=PUSH_ENABLED=false']
    proc = subprocess.Popen(cmd, cwd=RAIZ, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    codigo = 1
    try:
        for linea in proc.stdout:
            print(linea, end='', flush=True)
            if 'SHOT:' in linea:
                captura(args.udid, linea.split('SHOT:', 1)[1].strip())
            elif 'READY:en-camino' in linea:
                prep.pedido_en_camino()
        codigo = proc.wait()
    finally:
        if proc.poll() is None:
            proc.terminate()
        prep.limpiar()
        subprocess.run(['xcrun', 'simctl', 'status_bar', args.udid, 'clear'],
                       check=False)
    sys.exit(codigo)


if __name__ == '__main__':
    main()
