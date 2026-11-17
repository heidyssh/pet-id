
import {
  Organizacion,
  UsuarioOrganizacion,
  Rol,
  UsuarioRol,
} from '../models/index.js';

import { ROLES } from '../constants/roles.js';

export function autorizarOrganizacion({
  tiposPermitidos = ['veterinaria', 'refugio'],
  cargosPermitidos,
} = {}) {
  return async (req, res, next) => {
    try {
      if (!req.usuario?.id_usuario) {
        return res.status(401).json({
          success: false,
          message: 'Autenticación requerida',
        });
      }

      const idOrganizacion = req.params.idOrganizacion;

      if (!/^[1-9]\d*$/.test(String(idOrganizacion))) {
        return res.status(400).json({
          success: false,
          message: 'Organización inválida',
        });
      }

      const organizacion = await Organizacion.findByPk(
        idOrganizacion
      );

      if (
        !organizacion ||
        !organizacion.verificada ||
        !tiposPermitidos.includes(organizacion.tipo)
      ) {
        return res.status(404).json({
          success: false,
          message: 'Organización no disponible',
        });
      }

      const membresia = await UsuarioOrganizacion.findOne({
        where: {
          id_usuario: req.usuario.id_usuario,
          id_organizacion: idOrganizacion,
          activo: true,
        },
      });

      if (!membresia) {
        return res.status(403).json({
          success: false,
          message: 'No tenés acceso a esta organización',
        });
      }

      if (
        Array.isArray(cargosPermitidos) &&
        !cargosPermitidos.includes(membresia.cargo)
      ) {
        return res.status(403).json({
          success: false,
          message: 'No tenes permisos administrativos en esta organizacion',
        });
      }

      const relaciones = await UsuarioRol.findAll({
        where: { id_usuario: req.usuario.id_usuario },
        include: [{
          model: Rol,
          as: 'rol',
          required: true,
          attributes: ['nombre'],
        }],
      });

      const roles = relaciones.map(
        (relacion) => relacion.rol.nombre
      );

      const rolNecesario =
        organizacion.tipo === 'veterinaria'
          ? ROLES.PERSONAL_VETERINARIO
          : ROLES.PERSONAL_REFUGIO;

      if (!roles.includes(rolNecesario)) {
        return res.status(403).json({
          success: false,
          message: 'No tenés permisos para esta organización',
        });
      }

      req.organizacion = organizacion;
      req.membresia = membresia;

      return next();
    } catch (error) {
      return next(error);
    }
  };
}
