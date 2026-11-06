# PLANIFICACION DOCENTE - Gestion Pedagogica Colaborativa e Inclusiva (SaaS)

Plataforma web profesional multi-institucional (SaaS) disenada para establecimientos educacionales chilenos que implementan procesos de co-ensenanza y Programas de Integracion Escolar (PIE), articulando el trabajo colaborativo entre el **Docente de Aula Regular**, la **Educadora Diferencial**, el **Jefe de UTP**, el **Coordinador PIE** y el **Administrador del Colegio**.

---

## 1. Que hace la aplicacion

Implementa el ciclo completo de gestion pedagogica colaborativa e inclusiva en 5 etapas estructuradas y 10 modulos integrados:
1. **Arquitectura Multi-institucional (Multi-tenant):** Aislamiento estricto por colegio (`institution_id`) mediante Row Level Security (RLS) en PostgreSQL.
2. **Control de Acceso Basado en Roles (RBAC):** 5 roles oficiales con permisos granulares por curso y proteccion de datos sensibles de estudiantes PIE (sin acceso irrestricto para Administrador ni UTP).
3. **Asignacion Automatica del Equipo de Aula:** Al elegir un curso y asignatura, el sistema vincula automaticamente a la dupla Docente de Aula Regular + Educadora Diferencial verificada por la administracion.
4. **Constructor de Planificacion Conjunta (Secciones A - L):**
   - **Seccion A:** Identificacion general, curso, fecha, duracion (minutos) y equipo de aula.
   - **Seccion B:** Catalogo oficial de Objetivos de Aprendizaje (Bases Curriculares MINEDUC) con habilidades, conocimientos y actitudes, mas ingreso manual advertido cuando un catalogo especifico aun no se ha importado.
   - **Seccion C:** Redaccion conjunta del objetivo especifico de la clase.
   - **Seccion D:** Diferenciacion explicita entre **Tipo/Metodologia de Ensenanza** y **Modalidad de Co-ensenanza** (En equipo, Complementaria, Paralela, Por estaciones, etc.).
   - **Seccion E:** Organizacion de los tres momentos (**Inicio**, **Desarrollo**, **Cierre**) con validacion automatica de suma de tiempos frente a la duracion total de la clase.
   - **Seccion F:** Estrategias diversificadas organizadas bajo los 3 principios **DUA** (Compromiso, Representacion, Accion y Expresion) con justificacion de acceso, participacion y aprendizaje.
   - **Seccion G:** Apoyos especificos para estudiantes PIE del curso, centrados en barreras y adecuaciones pedagogicas (sin exponer diagnosticos clinicos en la planificacion general).
   - **Seccion H:** Matriz de responsabilidades por momento para cada profesional.
   - **Seccion I:** Gestion de recursos y carga de archivos con almacenamiento seguro.
   - **Seccion J:** Evaluacion de aprendizajes, indicadores de logro y adecuaciones de acceso/expresion.
   - **Seccion K:** Acuerdos de trabajo colaborativo con responsable, plazo y seguimiento historico.
   - **Seccion L:** Revision final consolidada, validador de completitud, control de versiones y envio.
5. **Flujo Independiente de Revision y Retroalimentacion (UTP + Coordinacion PIE):** Maquina de estados (`BORRADOR` -> `EN_REVISION` -> `SOLICITUD_AJUSTES` -> `REVISADO` -> `IMPLEMENTADO`) con doble visacion independiente y trazabilidad por version.
6. **Reflexion Pedagogica Post-Implementacion en 3 Columnas:**
   - **Columna A (Docente de Aula Regular):** Protegida contra edicion de otros roles.
   - **Columna B (Educadora Diferencial):** Protegida contra edicion de otros roles.
   - **Columna C (Reflexion Conjunta del Equipo):** Elaboracion compartida del equipo de aula.
7. **Exportacion PDF Imprimible con Privacidad Configurable:** Permite alternar entre iniciales protegidas o identificacion interna para resguardar datos personales de menores.

---

## 2. Stack Tecnologico

- **Frontend:** React 18, TypeScript 5 (tipado estricto), Vite 5, Tailwind CSS 3, Lucide Icons, jsPDF.
- **Backend & Persistencia:** Supabase (PostgreSQL 15+, Supabase Auth, Supabase Storage, Row Level Security).
- **Funciones Serverless:** Netlify Functions (`netlify/functions/`) para notificaciones por correo institucional libres de datos sensibles y validaciones de servidor.
- **Alojamiento y CI/CD:** Netlify (`netlify.toml` con cabeceras de seguridad HSTS, X-Frame-Options, CSP y SPA fallback).

---

## 3. Instalacion y Ejecucion Local

```bash
# 1. Instalar dependencias
npm install

# 2. Copiar archivo de variables de entorno
cp .env.example .env.local

# 3. Aplicar migraciones en su instancia de Supabase
npx supabase db push

# 4. Iniciar servidor de desarrollo
npm run dev
```

---

## 4. Creacion del Primer Administrador Institucional

1. Registre el establecimiento en la tabla `institutions` ejecutando el script semilla o desde el panel SQL de Supabase.
2. Cree el usuario en **Supabase Auth** con su correo institucional verificado.
3. Vincule al usuario en `institutional_memberships` con `role = 'ADMIN_COLEGIO'` y `invitation_verified = TRUE`.
4. Nunca se permite que un usuario seleccione libremente su rol desde el navegador; toda membresia requiere invitacion y verificacion institucional.

---

## 5. Despliegue en Netlify y Pendientes para Produccion Real

1. Conecte el repositorio Git a **Netlify**.
2. Netlify detectara automaticamente `netlify.toml` (`build command: npm run build`, `publish: dist`, `functions: netlify/functions`).
3. Configure las variables de entorno en **Site configuration > Environment variables** (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`).
4. **Pendientes obligatorios antes de un piloto con datos reales de menores de edad:**
   - Suscribir acuerdos de encargo de tratamiento de datos con proveedores cloud conforme a la **Ley 19.628** y **Ley 21.719**.
   - Configurar respaldos automaticos diarios Point-in-Time Recovery (PITR) en PostgreSQL.
   - Verificar dominio DNS institucional (SPF, DKIM, DMARC) en el proveedor de correo transaccional.
