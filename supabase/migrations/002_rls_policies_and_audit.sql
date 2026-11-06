-- =============================================================================
-- MIGRACION 002: POLITICAS ROW LEVEL SECURITY (RLS) Y REGLAS DE NEGOCIO EN BD
-- Garantiza aislamiento estricto entre colegios y control granular por rol/curso
-- =============================================================================

-- Funciones auxiliares de seguridad en esquema public
CREATE OR REPLACE FUNCTION public.user_has_institution_access(target_inst_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM institutional_memberships im
    WHERE im.institution_id = target_inst_id
      AND im.user_id = auth.uid()
      AND im.is_active = TRUE
      AND im.invitation_verified = TRUE
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.user_has_role(target_inst_id UUID, allowed_roles user_role_type[])
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM institutional_memberships im
    WHERE im.institution_id = target_inst_id
      AND im.user_id = auth.uid()
      AND im.role = ANY(allowed_roles)
      AND im.is_active = TRUE
      AND im.invitation_verified = TRUE
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.user_is_assigned_to_course(target_inst_id UUID, target_course_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM professional_assignments pa
    WHERE pa.institution_id = target_inst_id
      AND pa.course_id = target_course_id
      AND pa.active = TRUE
      AND pa.is_verified = TRUE
      AND (pa.regular_teacher_id = auth.uid() OR pa.special_educator_id = auth.uid())
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Activar RLS en todas las tablas
ALTER TABLE institutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE institutional_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE educational_support_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE plannings ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE reflections ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- 1. Aislamiento de Instituciones
CREATE POLICY "Aislamiento estricto por colegio" ON institutions
  FOR SELECT USING (public.user_has_institution_access(id));

CREATE POLICY "Solo Admin Colegio edita su institucion" ON institutions
  FOR UPDATE USING (public.user_has_role(id, ARRAY['ADMIN_COLEGIO']::user_role_type[]));

-- 2. Proteccion Granular de Antecedentes PIE (educational_support_records)
-- Regla Critica: Ni el Admin de Colegio ni el Jefe de UTP tienen acceso irrestricto por defecto
-- a los registros sensibles PIE salvo la Educadora Diferencial asignada al curso, el Docente del curso
-- (lectura pedagogica) y el Coordinador PIE de la institucion.
CREATE POLICY "Lectura restringida de registros PIE" ON educational_support_records
  FOR SELECT USING (
    public.user_has_role(institution_id, ARRAY['COORDINADOR_PIE']::user_role_type[])
    OR (
      public.user_has_role(institution_id, ARRAY['EDUCADORA_DIFERENCIAL', 'DOCENTE_AULA']::user_role_type[])
      AND public.user_is_assigned_to_course(institution_id, course_id)
    )
  );

CREATE POLICY "Escritura exclusiva Educadora Diferencial asignada o Coord PIE" ON educational_support_records
  FOR ALL USING (
    public.user_has_role(institution_id, ARRAY['COORDINADOR_PIE']::user_role_type[])
    OR (
      public.user_has_role(institution_id, ARRAY['EDUCADORA_DIFERENCIAL']::user_role_type[])
      AND public.user_is_assigned_to_course(institution_id, course_id)
    )
  );

-- 3. Control de Acceso a Planificaciones
CREATE POLICY "Lectura de planificaciones por equipo de aula o revisores de la institucion" ON plannings
  FOR SELECT USING (
    public.user_has_role(institution_id, ARRAY['JEFE_UTP', 'COORDINADOR_PIE', 'ADMIN_COLEGIO']::user_role_type[])
    OR (
      public.user_has_role(institution_id, ARRAY['DOCENTE_AULA', 'EDUCADORA_DIFERENCIAL']::user_role_type[])
      AND public.user_is_assigned_to_course(institution_id, course_id)
    )
  );

CREATE POLICY "Edicion de planificaciones solo por equipo del curso y en estados editables" ON plannings
  FOR UPDATE USING (
    public.user_is_assigned_to_course(institution_id, course_id)
    AND status IN ('BORRADOR', 'SOLICITUD_AJUSTES', 'REVISADO', 'IMPLEMENTADO')
  );

-- Trigger de validacion estricta de maquina de estados y prevencion de sobrescrituras en reflexion
CREATE OR REPLACE FUNCTION public.enforce_planning_state_machine()
RETURNS TRIGGER AS $$
BEGIN
  -- Impedir cambios manuales arbitrarios de estado
  IF OLD.status = 'BORRADOR' AND NEW.status NOT IN ('BORRADOR', 'EN_REVISION') THEN
    RAISE EXCEPTION 'Transicion invalida desde BORRADOR a %', NEW.status;
  END IF;

  IF OLD.status = 'EN_REVISION' AND NEW.status = 'REVISADO' THEN
    IF NEW.utp_review_decision != 'REVISADO_CONFORME' OR NEW.pie_review_decision != 'REVISADO_CONFORME' THEN
      RAISE EXCEPTION 'El estado REVISADO requiere aprobacion independiente de Jefe de UTP y Coordinador PIE';
    END IF;
  END IF;

  IF NEW.status = 'IMPLEMENTADO' AND OLD.status NOT IN ('REVISADO', 'IMPLEMENTADO') THEN
    RAISE EXCEPTION 'Solo una planificacion en estado REVISADO puede marcarse como IMPLEMENTADO';
  END IF;

  NEW.lock_version := OLD.lock_version + 1;
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_planning_state_machine
  BEFORE UPDATE ON plannings
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_planning_state_machine();
