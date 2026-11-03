
import { Rol, UsuarioRol } from '../models/index.js';

// Verificar que el usuario tenga al menos
// uno de los roles permitidos.
export function autorizarRoles(...rolesPermitidos) {
  if (rolesPermitidos.length === 0) {
    throw new Error('Se requiere al menos un rol');
  }

  return async (req, res, next) => {
    try {
      if (!req.usuario?.id_usuario) {
        return res.status(401).json({
          success: false,
          message: 'Autenticación requerida',
        });
      }

      const relaciones = await UsuarioRol.findAll({
        where: {
          id_usuario: req.usuario.id_usuario,
        },
        include: [{
          model: Rol,
          as: 'rol',
          attributes: ['nombre'],
          required: true,
        }],
      });

      const rolesUsuario = relaciones.map(
        (relacion) => relacion.rol.nombre
      );

      const autorizado = rolesPermitidos.some(
        (rol) => rolesUsuario.includes(rol)
      );

      if (!autorizado) {
        return res.status(403).json({
          success: false,
          message: 'No tenés permisos para esta acción',
        });
      }

      req.usuario.roles = rolesUsuario;

      return next();
    } catch (error) {
      return next(error);
    }
  };
}
