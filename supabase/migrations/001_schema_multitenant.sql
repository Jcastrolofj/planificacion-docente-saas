-- =============================================================================
-- MIGRACION 001: ESQUEMA RELACIONAL MULTI-INSTITUCIONAL (SAAS)
-- Plataforma: PLANIFICACION DOCENTE - Gestion Pedagogica Colaborativa e Inclusiva
-- Normativa considerada: Ley 19.628, Ley 21.719, Decreto 170/2009, Decreto 83/2015
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums de sistema
CREATE TYPE user_role_type AS ENUM (
  'ADMIN_COLEGIO',
  'DOCENTE_AULA',
  'EDUCADORA_DIFERENCIAL',
  'JEFE_UTP',
  'COORDINADOR_PIE'
);

CREATE TYPE planning_status_type AS ENUM (
  'BORRADOR',
  'EN_REVISION',
  'SOLICITUD_AJUSTES',
  'REVISADO',
  'IMPLEMENTADO'
);

CREATE TYPE reflection_status_type AS ENUM (
  'PENDIENTE',
  'EN_ELABORACION',
  'COMPLETADA'
);

CREATE TYPE review_decision_type AS ENUM (
  'PENDIENTE',
  'OBSERVADO_SOLICITA_AJUSTES',
  'REVISADO_CONFORME'
);

CREATE TYPE moment_type AS ENUM ('INICIO', 'DESARROLLO', 'CIERRE');
CREATE TYPE dua_principle_type AS ENUM ('COMPROMISO', 'REPRESENTACION', 'ACCION_EXPRESION');

-- 1. INSTITUCIONES (Tenants)
CREATE TABLE institutions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rbd VARCHAR(20) UNIQUE NOT NULL,
  name VARCHAR(200) NOT NULL,
  commune VARCHAR(100) NOT NULL,
  region VARCHAR(100) NOT NULL,
  email_domain VARCHAR(120) NOT NULL,
  logo_url TEXT,
  primary_color VARCHAR(20) DEFAULT '#1e3a8a',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  settings JSONB NOT NULL DEFAULT '{"require_both_reviews": true, "hide_student_surnames_in_pdf": true}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. USUARIOS Y 3. PERFILES
CREATE TABLE profiles (
  id UUID PRIMARY KEY, -- Vinculado a auth.users(id)
  email VARCHAR(255) UNIQUE NOT NULL,
  full_name VARCHAR(200) NOT NULL,
  specialty VARCHAR(150),
  phone VARCHAR(50),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. MEMBRESIAS INSTITUCIONALES Y 5. ROLES Y PERMISOS
CREATE TABLE institutional_memberships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role user_role_type NOT NULL,
  invited_by UUID REFERENCES profiles(id),
  invitation_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(institution_id, user_id, role)
);

CREATE TABLE roles_permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role user_role_type NOT NULL,
  permission_code VARCHAR(100) NOT NULL,
  description TEXT NOT NULL,
  UNIQUE(role, permission_code)
);

-- 6. PERIODOS ACADEMICOS
CREATE TABLE academic_periods (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  name VARCHAR(100) NOT NULL, -- ej. "Año Escolar 2026 - Semestre 2"
  is_current BOOLEAN NOT NULL DEFAULT FALSE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  UNIQUE(institution_id, year, name)
);

-- 7. CURSOS Y NIVELES
CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  academic_period_id UUID NOT NULL REFERENCES academic_periods(id) ON DELETE CASCADE,
  level_code VARCHAR(50) NOT NULL, -- ej. "5_BASICO", "6_BASICO"
  level_name VARCHAR(100) NOT NULL, -- ej. "5° Básico"
  section VARCHAR(20) NOT NULL, -- ej. "A"
  student_count INTEGER NOT NULL DEFAULT 30,
  course_characterization TEXT DEFAULT '',
  pie_general_characterization TEXT DEFAULT '',
  characterization_updated_by UUID REFERENCES profiles(id),
  characterization_updated_at TIMESTAMPTZ,
  UNIQUE(institution_id, academic_period_id, level_code, section)
);

-- 8. ASIGNATURAS
CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  code VARCHAR(40) NOT NULL,
  name VARCHAR(120) NOT NULL,
  UNIQUE(institution_id, code)
);

-- 9. UNIDADES
CREATE TABLE units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  level_code VARCHAR(50) NOT NULL,
  unit_number INTEGER NOT NULL,
  title VARCHAR(200) NOT NULL,
  description TEXT
);

-- 10. ASIGNACIONES DE PROFESIONALES (EQUIPOS DE AULA)
CREATE TABLE professional_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  regular_teacher_id UUID NOT NULL REFERENCES profiles(id),
  special_educator_id UUID NOT NULL REFERENCES profiles(id),
  other_professionals JSONB DEFAULT '[]'::jsonb,
  assigned_by UUID NOT NULL REFERENCES profiles(id),
  is_verified BOOLEAN NOT NULL DEFAULT TRUE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(institution_id, course_id, subject_id)
);

-- 11. ESTUDIANTES Y 12. REGISTROS DE APOYOS EDUCATIVOS PIE
-- Nota de Privacidad: No almacena diagnosticos clinicos sensibles en vista general;
-- privilegia barreras de acceso y medidas pedagogicas conforme al Decreto 83/2015.
CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE RESTRICT,
  internal_code VARCHAR(50) NOT NULL, -- Identificador interno del establecimiento
  display_initials VARCHAR(20) NOT NULL, -- Para vistas protegidas / exportacion PDF
  full_name VARCHAR(200) NOT NULL,
  requires_pie_support BOOLEAN NOT NULL DEFAULT FALSE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(institution_id, internal_code)
);

CREATE TABLE educational_support_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  authorized_educator_id UUID NOT NULL REFERENCES profiles(id),
  support_category VARCHAR(80) NOT NULL, -- ej. "Apoyo Transitorio (NEET)" o "Apoyo Permanente (NEEP)"
  identified_barriers TEXT NOT NULL,
  recommended_strategies TEXT NOT NULL,
  curricular_adjustments TEXT NOT NULL,
  evaluation_accommodations TEXT NOT NULL,
  updated_by UUID NOT NULL REFERENCES profiles(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 13. CATALOGO CURRICULAR Y 14. OBJETIVOS DE APRENDIZAJE (BASES CURRICULARES CHILE)
CREATE TABLE curricular_catalog (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID REFERENCES institutions(id) ON DELETE CASCADE, -- NULL = Catalogo Oficial MINEDUC
  mineduc_decree VARCHAR(120) NOT NULL,
  version_year INTEGER NOT NULL,
  is_official BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE learning_objectives (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  catalog_id UUID NOT NULL REFERENCES curricular_catalog(id) ON DELETE CASCADE,
  institution_id UUID REFERENCES institutions(id) ON DELETE CASCADE,
  level_code VARCHAR(50) NOT NULL,
  subject_code VARCHAR(40) NOT NULL,
  unit_number INTEGER,
  oa_code VARCHAR(40) NOT NULL, -- ej. "OA 04", "OA 06"
  official_description TEXT NOT NULL,
  skills JSONB NOT NULL DEFAULT '[]'::jsonb,
  knowledge JSONB NOT NULL DEFAULT '[]'::jsonb,
  attitudes JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_custom_manual BOOLEAN NOT NULL DEFAULT FALSE
);

-- 15. PLANIFICACIONES Y 16. VERSIONES DE PLANIFICACIONES
CREATE TABLE plannings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE RESTRICT,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
  unit_id UUID NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
  assignment_id UUID NOT NULL REFERENCES professional_assignments(id),
  regular_teacher_id UUID NOT NULL REFERENCES profiles(id),
  special_educator_id UUID NOT NULL REFERENCES profiles(id),
  class_date DATE NOT NULL,
  duration_minutes INTEGER NOT NULL DEFAULT 90 CHECK (duration_minutes > 0 AND duration_minutes <= 240),
  learning_objective_id UUID REFERENCES learning_objectives(id),
  selected_skills JSONB NOT NULL DEFAULT '[]'::jsonb,
  selected_knowledge JSONB NOT NULL DEFAULT '[]'::jsonb,
  selected_attitudes JSONB NOT NULL DEFAULT '[]'::jsonb,
  specific_class_objective TEXT NOT NULL DEFAULT '',
  teaching_methodology VARCHAR(120) NOT NULL DEFAULT '',
  coteaching_modality VARCHAR(120) NOT NULL DEFAULT '',
  status planning_status_type NOT NULL DEFAULT 'BORRADOR',
  reflection_status reflection_status_type NOT NULL DEFAULT 'PENDIENTE',
  utp_review_decision review_decision_type NOT NULL DEFAULT 'PENDIENTE',
  pie_review_decision review_decision_type NOT NULL DEFAULT 'PENDIENTE',
  current_version INTEGER NOT NULL DEFAULT 1,
  lock_version INTEGER NOT NULL DEFAULT 1, -- Control de concurrencia optimista multiusuario
  last_edited_by UUID REFERENCES profiles(id),
  submitted_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  implemented_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE planning_versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  planning_id UUID NOT NULL REFERENCES plannings(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  status_at_snapshot planning_status_type NOT NULL,
  snapshot_payload JSONB NOT NULL,
  created_by UUID NOT NULL REFERENCES profiles(id),
  change_summary TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(planning_id, version_number)
);

-- 17. MOMENTOS Y ACTIVIDADES DE CLASE (INICIO, DESARROLLO, CIERRE)
CREATE TABLE class_moments_activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  planning_id UUID NOT NULL REFERENCES plannings(id) ON DELETE CASCADE,
  moment moment_type NOT NULL,
  sequence_order INTEGER NOT NULL DEFAULT 1,
  title VARCHAR(200) NOT NULL,
  purpose_or_sequence TEXT NOT NULL,
  regular_teacher_participation TEXT NOT NULL,
  special_educator_participation TEXT NOT NULL,
  diversified_strategies_summary TEXT,
  resources_needed TEXT,
  estimated_minutes INTEGER NOT NULL CHECK (estimated_minutes >= 0),
  UNIQUE(planning_id, moment, sequence_order)
);

-- 18. ESTRATEGIAS DUA (COMPROMISO, REPRESENTACION, ACCION Y EXPRESION)
CREATE TABLE dua_strategies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  planning_id UUID NOT NULL REFERENCES plannings(id) ON DELETE CASCADE,
  principle dua_principle_type NOT NULL,
  strategy_name VARCHAR(150) NOT NULL,
  associated_moment moment_type NOT NULL,
  pedagogical_justification TEXT NOT NULL -- Como favorece acceso, participacion y aprendizaje
);

-- 19. APOYOS ESPECIFICOS POR ESTUDIANTE EN LA CLASE
CREATE TABLE specific_supports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  planning_id UUID NOT NULL REFERENCES plannings(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
  support_record_id UUID REFERENCES educational_support_records(id),
  support_type VARCHAR(150) NOT NULL,
  addressed_barriers TEXT NOT NULL,
  implemented_strategies TEXT NOT NULL,
  resources_or_adjustments TEXT NOT NULL,
  responsible_professional_id UUID NOT NULL REFERENCES profiles(id),
  application_moment moment_type NOT NULL
);

-- 20. DISTRIBUCION DE ROLES Y RESPONSABILIDADES
CREATE TABLE responsibilities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  planning_id UUID NOT NULL REFERENCES plannings(id) ON DELETE CASCADE,
  moment moment_type NOT NULL,
  regular_teacher_tasks TEXT NOT NULL,
  special_educator_tasks TEXT NOT NULL,
  other_professional_tasks TEXT DEFAULT ''
);

-- 21. RECURSOS Y ARCHIVOS ADJUNTOS (CON STORAGE SEGURO)
CREATE TABLE resources_files (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  planning_id UUID REFERENCES plannings(id) ON DELETE CASCADE,
  activity_moment moment_type,
  title VARCHAR(200) NOT NULL,
  resource_type VARCHAR(80) NOT NULL, -- Visual, Auditivo, Material Concreto, Guia, Presentacion
  storage_bucket_path TEXT,
  mime_type VARCHAR(100),
  file_size_bytes BIGINT,
  is_reusable_catalog BOOLEAN NOT NULL DEFAULT TRUE,
  uploaded_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 22. INSTRUMENTOS Y EVALUACION DE APRENDIZAJES
CREATE TABLE evaluation_instruments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  planning_id UUID NOT NULL REFERENCES plannings(id) ON DELETE CASCADE,
  what_is_evaluated TEXT NOT NULL,
  how_is_evaluated TEXT NOT NULL,
  instrument_type VARCHAR(150) NOT NULL, -- Rubrica, Lista de cotejo, Ticket de salida, Escala
  achievement_indicators JSONB NOT NULL DEFAULT '[]'::jsonb,
  expected_evidence TEXT NOT NULL,
  responsible_id UUID NOT NULL REFERENCES profiles(id),
  dua_evaluation_accommodations TEXT NOT NULL
);

-- 23. ACUERDOS DEL TRABAJO COLABORATIVO
CREATE TABLE collaborative_agreements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  planning_id UUID NOT NULL REFERENCES plannings(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  responsible_id UUID NOT NULL REFERENCES profiles(id),
  due_date DATE NOT NULL,
  status VARCHAR(40) NOT NULL DEFAULT 'PENDIENTE', -- PENDIENTE, EN_PROGRESO, CUMPLIDO
  observations TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 24. REVISIONES Y 25. OBSERVACIONES (UTP Y COORDINACION PIE)
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  planning_id UUID NOT NULL REFERENCES plannings(id) ON DELETE CASCADE,
  planning_version INTEGER NOT NULL,
  reviewer_id UUID NOT NULL REFERENCES profiles(id),
  reviewer_role user_role_type NOT NULL CHECK (reviewer_role IN ('JEFE_UTP', 'COORDINADOR_PIE')),
  decision review_decision_type NOT NULL,
  general_observations TEXT NOT NULL,
  achieved_aspects TEXT NOT NULL,
  improvement_aspects TEXT NOT NULL,
  recommendations TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE observations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  review_id UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  planning_id UUID NOT NULL REFERENCES plannings(id) ON DELETE CASCADE,
  section_code VARCHAR(50) NOT NULL, -- ej. "SECCION_B_OA", "SECCION_E_DESARROLLO", "SECCION_F_DUA"
  comment TEXT NOT NULL,
  requires_adjustment BOOLEAN NOT NULL DEFAULT FALSE,
  resolved BOOLEAN NOT NULL DEFAULT FALSE,
  author_response TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 26. REFLEXIONES PEDAGOGICAS POST-IMPLEMENTACION (3 COLUMNAS INDEPENDIENTES)
CREATE TABLE reflections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  planning_id UUID UNIQUE NOT NULL REFERENCES plannings(id) ON DELETE CASCADE,
  -- Columna A: Docente de Aula Regular
  regular_activities_developed VARCHAR(20) CHECK (regular_activities_developed IN ('SI', 'PARCIALMENTE', 'NO')),
  regular_effective_strategies TEXT DEFAULT '',
  regular_improvements TEXT DEFAULT '',
  regular_completed_by UUID REFERENCES profiles(id),
  regular_updated_at TIMESTAMPTZ,
  -- Columna B: Educadora Diferencial
  special_supports_effective VARCHAR(20) CHECK (special_supports_effective IN ('SI', 'PARCIALMENTE', 'NO')),
  special_diversified_strategies TEXT DEFAULT '',
  special_suggestions_next TEXT DEFAULT '',
  special_completed_by UUID REFERENCES profiles(id),
  special_updated_at TIMESTAMPTZ,
  -- Columna C: Reflexion Conjunta del Equipo de Aula
  joint_what_worked_well TEXT DEFAULT '',
  joint_difficulties TEXT DEFAULT '',
  joint_agreements_next_class TEXT DEFAULT '',
  joint_updated_by UUID REFERENCES profiles(id),
  joint_updated_at TIMESTAMPTZ,
  is_finalized BOOLEAN NOT NULL DEFAULT FALSE,
  finalized_at TIMESTAMPTZ
);

-- 27. NOTIFICACIONES INTERNAS Y REGISTRO DE DESPACHO DE CORREO
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  recipient_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  planning_id UUID REFERENCES plannings(id) ON DELETE CASCADE,
  event_type VARCHAR(80) NOT NULL,
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL, -- Libre de datos clinicos/sensibles de estudiantes
  target_route VARCHAR(255) NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  email_dispatched BOOLEAN NOT NULL DEFAULT FALSE,
  dedup_key VARCHAR(180) UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 28. REGISTROS DE AUDITORIA INMUTABLES (TRAZABILIDAD DE DATOS PROTEGIDOS)
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE CASCADE,
  actor_user_id UUID REFERENCES profiles(id),
  actor_role user_role_type,
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(80) NOT NULL,
  entity_id UUID NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb, -- Nunca almacena diagnosticos clinicos en texto plano
  ip_hash VARCHAR(128),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indices de alto rendimiento para aislamiento multi-tenant y filtros
CREATE INDEX idx_memberships_inst_user ON institutional_memberships(institution_id, user_id);
CREATE INDEX idx_courses_inst_period ON courses(institution_id, academic_period_id);
CREATE INDEX idx_assignments_inst_course ON professional_assignments(institution_id, course_id);
CREATE INDEX idx_students_inst_course ON students(institution_id, course_id);
CREATE INDEX idx_plannings_inst_status ON plannings(institution_id, status, class_date);
CREATE INDEX idx_plannings_course_authors ON plannings(course_id, regular_teacher_id, special_educator_id);
CREATE INDEX idx_notifications_recipient ON notifications(institution_id, recipient_user_id, is_read);
CREATE INDEX idx_audit_inst_created ON audit_logs(institution_id, created_at DESC);
