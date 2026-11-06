
import {
  Especie,
  Raza,
} from '../models/index.js';

export async function listarEspecies() {
  return Especie.findAll({
    attributes: ['id_especie', 'nombre'],
    order: [['nombre', 'ASC']],
  });
}

export async function listarRazas(idEspecie) {
  return Raza.findAll({
    attributes: [
      'id_raza',
      'id_especie',
      'nombre',
    ],
    ...(idEspecie
      ? { where: { id_especie: idEspecie } }
      : {}),
    order: [['nombre', 'ASC']],
  });
}
