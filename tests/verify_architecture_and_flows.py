import sqlite3
import unittest

class PlatformVerificationEngine:
    def __init__(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.row_factory = sqlite3.Row
        self._init_schema()

    def _init_schema(self):
        c = self.conn.cursor()
        c.executescript('''
            CREATE TABLE institutions (id TEXT PRIMARY KEY, name TEXT, rbd TEXT UNIQUE);
            CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT UNIQUE, full_name TEXT, active INTEGER DEFAULT 1);
            CREATE TABLE memberships (
                institution_id TEXT, user_id TEXT, role TEXT, verified INTEGER DEFAULT 1,
                PRIMARY KEY (institution_id, user_id, role)
            );
            CREATE TABLE courses (
                id TEXT PRIMARY KEY, institution_id TEXT, name TEXT,
                characterization TEXT DEFAULT '', pie_characterization TEXT DEFAULT ''
            );
            CREATE TABLE assignments (
                id TEXT PRIMARY KEY, institution_id TEXT, course_id TEXT, subject TEXT,
                regular_teacher_id TEXT, special_educator_id TEXT, verified INTEGER DEFAULT 1
            );
            CREATE TABLE students_pie (
                id TEXT PRIMARY KEY, institution_id TEXT, course_id TEXT,
                internal_code TEXT, initials TEXT, support_category TEXT,
                barriers TEXT, adjustments TEXT
            );
            CREATE TABLE plannings (
                id TEXT PRIMARY KEY, institution_id TEXT, course_id TEXT, subject TEXT,
                regular_teacher_id TEXT, special_educator_id TEXT,
                oa_code TEXT DEFAULT '', specific_objective TEXT DEFAULT '',
                teaching_type TEXT DEFAULT '', coteaching_modality TEXT DEFAULT '',
                duration_minutes INTEGER DEFAULT 90,
                inicio_minutes INTEGER DEFAULT 0, desarrollo_minutes INTEGER DEFAULT 0, cierre_minutes INTEGER DEFAULT 0,
                dua_strategies_count INTEGER DEFAULT 0,
                specific_supports_count INTEGER DEFAULT 0,
                resources_count INTEGER DEFAULT 0,
                agreements_count INTEGER DEFAULT 0,
                status TEXT DEFAULT 'BORRADOR',
                utp_decision TEXT DEFAULT 'PENDIENTE',
                pie_decision TEXT DEFAULT 'PENDIENTE',
                version INTEGER DEFAULT 1,
                reflection_status TEXT DEFAULT 'PENDIENTE',
                reg_ref_done TEXT DEFAULT '', reg_ref_text TEXT DEFAULT '',
                spec_ref_done TEXT DEFAULT '', spec_ref_text TEXT DEFAULT '',
                joint_ref_text TEXT DEFAULT ''
            );
            CREATE TABLE reviews (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                institution_id TEXT, planning_id TEXT, version INTEGER,
                reviewer_id TEXT, role TEXT, decision TEXT, comment TEXT
            );
            CREATE TABLE notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                institution_id TEXT, recipient_id TEXT, planning_id TEXT,
                event_type TEXT, safe_body TEXT
            );
        ''')
        self.conn.commit()

    def get_role(self, inst_id, user_id):
        cur = self.conn.execute(
            "SELECT role FROM memberships WHERE institution_id=? AND user_id=? AND verified=1",
            (inst_id, user_id)
        )
        row = cur.fetchone()
        return row["role"] if row else None

    def is_assigned(self, inst_id, course_id, user_id):
        cur = self.conn.execute(
            "SELECT 1 FROM assignments WHERE institution_id=? AND course_id=? AND verified=1 AND (regular_teacher_id=? OR special_educator_id=?)",
            (inst_id, course_id, user_id, user_id)
        )
        return cur.fetchone() is not None

    def query_plannings(self, actor_inst_id, actor_user_id, target_inst_id):
        # Regla 1: Aislamiento estricto multi-tenant
        if actor_inst_id != target_inst_id:
            raise PermissionError("AISLAMIENTO_MULTITENANT: Acceso denegado a datos de otra institucion.")
        role = self.get_role(actor_inst_id, actor_user_id)
        if not role:
            raise PermissionError("RBAC: Usuario sin membresia verificada en la institucion.")
        if role in ("JEFE_UTP", "COORDINADOR_PIE", "ADMIN_COLEGIO"):
            return self.conn.execute("SELECT * FROM plannings WHERE institution_id=?", (actor_inst_id,)).fetchall()
        return self.conn.execute(
            "SELECT * FROM plannings WHERE institution_id=? AND (regular_teacher_id=? OR special_educator_id=?)",
            (actor_inst_id, actor_user_id, actor_user_id)
        ).fetchall()

    def query_pie_sensitive_records(self, actor_inst_id, actor_user_id, course_id):
        role = self.get_role(actor_inst_id, actor_user_id)
        # Regla 4 y 5: Ni ADMIN_COLEGIO ni JEFE_UTP tienen acceso irrestricto a antecedentes sensibles PIE;
        # Y la Educadora Diferencial solo accede a cursos asignados.
        if role == "COORDINADOR_PIE":
            return self.conn.execute("SELECT * FROM students_pie WHERE institution_id=? AND course_id=?", (actor_inst_id, course_id)).fetchall()
        if role in ("EDUCADORA_DIFERENCIAL", "DOCENTE_AULA"):
            if not self.is_assigned(actor_inst_id, course_id, actor_user_id):
                raise PermissionError("RBAC_CURSO: Profesional no asignado a este curso.")
            return self.conn.execute("SELECT * FROM students_pie WHERE institution_id=? AND course_id=?", (actor_inst_id, course_id)).fetchall()
        raise PermissionError(f"PRIVACIDAD_PIE: El rol {role} no tiene acceso a registros individuales sensibles PIE.")

    def attempt_self_role_escalation(self, inst_id, user_id, requested_role):
        raise PermissionError("SEGURIDAD_RBAC: Prohibido auto-asignar o escalar roles desde el cliente.")

    def update_reflection(self, inst_id, actor_id, planning_id, column_target, status_choice, text_val):
        p = self.conn.execute("SELECT * FROM plannings WHERE id=? AND institution_id=?", (planning_id, inst_id)).fetchone()
        if not p:
            raise PermissionError("Planificacion no encontrada.")
        if p["status"] != "IMPLEMENTADO":
            raise ValueError("Solo se puede reflexionar sobre una clase en estado IMPLEMENTADO.")
        role = self.get_role(inst_id, actor_id)
        if not self.is_assigned(inst_id, p["course_id"], actor_id):
            raise PermissionError("No pertenece al equipo de aula de esta planificacion.")
        if column_target == "REGULAR":
            if role != "DOCENTE_AULA":
                raise PermissionError("PROTECCION_COLUMNA: Solo el Docente de Aula Regular puede editar su reflexion individual.")
            self.conn.execute("UPDATE plannings SET reg_ref_done=?, reg_ref_text=? WHERE id=?", (status_choice, text_val, planning_id))
        elif column_target == "ESPECIAL":
            if role != "EDUCADORA_DIFERENCIAL":
                raise PermissionError("PROTECCION_COLUMNA: Solo la Educadora Diferencial puede editar su reflexion individual.")
            self.conn.execute("UPDATE plannings SET spec_ref_done=?, spec_ref_text=? WHERE id=?", (status_choice, text_val, planning_id))
        elif column_target == "CONJUNTA":
            if role not in ("DOCENTE_AULA", "EDUCADORA_DIFERENCIAL"):
                raise PermissionError("Solo el equipo de aula puede editar la reflexion conjunta.")
            self.conn.execute("UPDATE plannings SET joint_ref_text=? WHERE id=?", (text_val, planning_id))
        self.conn.commit()
        p_after = self.conn.execute("SELECT * FROM plannings WHERE id=?", (planning_id,)).fetchone()
        if p_after["reg_ref_text"] and p_after["spec_ref_text"] and p_after["joint_ref_text"]:
            self.conn.execute("UPDATE plannings SET reflection_status='COMPLETADA' WHERE id=?", (planning_id,))
        else:
            self.conn.execute("UPDATE plannings SET reflection_status='EN_ELABORACION' WHERE id=?", (planning_id,))
        self.conn.commit()

if __name__ == '__main__':
    print("Verification module loaded.")
