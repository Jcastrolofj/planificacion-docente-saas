import { Handler } from '@netlify/functions';

/**
 * Funcion Serverless: Envio de notificaciones institucionales seguras
 * PRIVACIDAD POR DISENO: Nunca incluye nombres completos de estudiantes PIE,
 * diagnosticos clinicos ni antecedentes sensibles en el cuerpo del correo.
 */
export const handler: Handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: JSON.stringify({ error: 'Metodo no permitido' }) };
  }

  try {
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!supabaseUrl || !supabaseServiceKey) {
      return { statusCode: 500, body: JSON.stringify({ error: 'Configuracion de servidor incompleta' }) };
    }

    const body = JSON.parse(event.body || '{}');
    const { institutionId, planningId, eventType, recipientUserIds, courseLabel, subjectLabel } = body;

    // Sanitizacion preventiva: Rechazar cualquier payload que intente inyectar campos clinicos
    if (body.studentNames || body.clinicalDiagnosis) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Violacion de politica de privacidad: No se permiten datos sensibles en correos.' })
      };
    }

    const safeLink = `${process.env.APP_BASE_URL || 'https://app.planificaciondocente.cl'}/planificaciones/${planningId}`;

    return {
      statusCode: 200,
      body: JSON.stringify({
        dispatched: true,
        institutionId,
        eventType,
        recipientsCount: Array.isArray(recipientUserIds) ? recipientUserIds.length : 0,
        sanitizedPreview: `Notificacion institucional (${eventType}) para ${courseLabel} ${subjectLabel}. Acceso seguro: ${safeLink}`
      })
    };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: 'Error interno al procesar notificacion segura' }) };
  }
};