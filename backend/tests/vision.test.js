import assert from 'node:assert/strict';

process.env.VISION_PROVIDER = 'roboflow';
process.env.ROBOFLOW_API_KEY = 'clave-de-prueba';
process.env.ROBOFLOW_MODEL_ID = 'mascotas-prueba/1';

globalThis.fetch = async (url, opciones) => {
  assert.equal(
    url,
    'https://serverless.roboflow.com/mascotas-prueba/1'
  );
  assert.equal(opciones.method, 'POST');
  assert.equal(
    opciones.headers.Authorization,
    'Bearer clave-de-prueba'
  );
  assert.equal(opciones.headers['Content-Type'], 'application/x-www-form-urlencoded');
  assert.equal(opciones.body, Buffer.from('imagen-de-prueba').toString('base64'));
  return new Response(JSON.stringify({
    image: { width: 1000, height: 500 },
    predictions: [{
      class: 'dog',
      confidence: 0.91,
      x: 500,
      y: 250,
      width: 400,
      height: 200,
    }],
  }), { status: 200, headers: { 'Content-Type': 'application/json' } });
};

const { detectarAnimal, proveedorVisualConfigurado } = await import(
  '../src/services/vision.service.js'
);

assert.equal(proveedorVisualConfigurado(), true);
const resultado = await detectarAnimal(Buffer.from('imagen-de-prueba'));
assert.equal(resultado.etiqueta, 'dog');
assert.equal(resultado.confianza, 0.91);
assert.deepEqual(resultado.caja, {
  x_min: 0.3,
  y_min: 0.3,
  x_max: 0.7,
  y_max: 0.7,
});

console.log('Adaptador visual Roboflow: OK');
