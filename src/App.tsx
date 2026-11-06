import React, { useState, useMemo } from 'react';
import {
  ShieldCheck, BookOpen, Users, CheckCircle2, AlertTriangle, Clock,
  FileText, Send, Eye, Lock, Upload, CheckSquare, Sparkles, Filter,
  Building2, Bell, History, Download, Plus, RefreshCw
} from 'lucide-react';
import { UserRole, PlanningStatus, ReflectionStatus, ReviewDecision, RBAC_PERMISSIONS } from './types/domain';

const OFFICIAL_OA_CATALOG = [
  {
    id: 'oa-ing-6-05',
    levelCode: '6_BASICO',
    subject: 'Inglés',
    unit: 'Unidad 2: Around Town & Daily Life',
    oaCode: 'OA 05',
    description: 'Leer y demostrar comprensión de textos adaptados y auténticos simples no literarios, que contengan palabras de uso frecuente, familias de palabras y repetición de frases, identificando ideas generales e información explícita.',
    skills: ['Comprensión de lectura (Reading)', 'Identificación de información explícita', 'Uso de apoyos visuales'],
    knowledge: ['Vocabulario temático de la ciudad y ocupaciones', 'Preposiciones de lugar', 'Presente simple descriptivo'],
    attitudes: ['Manifestar una actitud positiva frente a sí mismo y sus capacidades para aprender un nuevo idioma.']
  }
];

export default function PlanificacionDocenteApp() {
  const [activeInstitutionId, setActiveInstitutionId] = useState<'inst-1' | 'inst-2'>('inst-1');
  const [activeRole, setActiveRole] = useState<UserRole>('DOCENTE_AULA');
  const [activeModule, setActiveModule] = useState<
    'DASHBOARD' | 'CONSTRUCTOR' | 'EQUIPOS' | 'PIE_MODULE' | 'REVISION' | 'REFLEXION' | 'HISTORIAL'
  >('DASHBOARD');
  const [autoSaveState, setAutoSaveState] = useState<'GUARDADO' | 'GUARDANDO'>('GUARDADO');

  const permissions = RBAC_PERMISSIONS[activeRole];

  const [planning, setPlanning] = useState({
    id: 'PLAN-2026-089',
    institutionId: 'inst-1',
    courseName: '6° Básico A',
    subject: 'Inglés',
    unit: 'Unidad 2: Around Town & Daily Life',
    durationMinutes: 90,
    regularTeacherName: 'Prof. Joaquín Castro (Docente de Aula Regular)',
    specialEducatorName: 'Ed. Dif. Catalina Carrasco (Educadora Diferencial PIE)',
    status: 'BORRADOR' as PlanningStatus,
    reflectionStatus: 'PENDIENTE' as ReflectionStatus,
    version: 1,
    moments: {
      inicio: { minutes: 15 },
      desarrollo: { minutes: 55 },
      cierre: { minutes: 20 }
    },
    specificSupports: [
      {
        studentCode: 'EST-2026-014',
        initials: 'M.A.R.',
        supportType: 'Apoyo Educativo Transitorio',
        barriers: 'Fatiga lectora ante bloques extensos de texto en segundo idioma.',
        strategies: 'Fragmentación del texto en párrafos numerados + instrucciones secuenciadas paso a paso.',
        adjustments: 'Glosario ilustrado en mesa y uso de organizador gráfico con conectores pre-estructurados.'
      }
    ],
    reflection: {
      regularCompleted: 'SI',
      regularEffectiveStrategies: 'El modelo de enseñanza por estaciones mantuvo el foco.',
      regularImprovements: 'Destinar 5 minutos adicionales a la transición.',
      specialCompleted: 'SI',
      specialDiversifiedStrategies: 'El glosario pictográfico permitió autonomía total.',
      specialSuggestionsNext: 'Incorporar apoyo auditivo en la estación 1.',
      jointWorkedWell: 'La co-enseñanza permitió atender de forma personalizada.',
      jointDifficulties: 'El tiempo de cierre se vio ajustado.',
      jointNextAgreements: 'Utilizar temporizador visual proyectado en pizarra.'
    }
  });

  const totalMomentsMinutes = useMemo(() => {
    return Number(planning.moments.inicio.minutes) + Number(planning.moments.desarrollo.minutes) + Number(planning.moments.cierre.minutes);
  }, [planning.moments]);

  const handleSendToReview = () => {
    if (totalMomentsMinutes !== planning.durationMinutes) {
      alert('Por favor ajuste los tiempos para que sumen exactamente la duración de la clase.');
      return;
    }
    setAutoSaveState('GUARDANDO');
    setTimeout(() => {
      setPlanning(prev => ({ ...prev, status: 'EN_REVISION' }));
      setAutoSaveState('GUARDADO');
    }, 300);
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 flex flex-col font-sans">
      <header className="bg-indigo-950 text-white border-b border-indigo-900 px-6 py-3 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-indigo-800 rounded-lg">
            <BookOpen className="w-6 h-6 text-indigo-200" />
          </div>
          <div>
            <h1 className="text-base font-bold tracking-tight">PLANIFICACIÓN DOCENTE — Gestión Pedagógica Inclusiva</h1>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <select value={activeRole} onChange={e => setActiveRole(e.target.value as UserRole)} className="bg-indigo-800 text-xs font-medium text-white border border-indigo-600 rounded-lg px-3 py-1.5">
            <option value="DOCENTE_AULA">Rol: Docente de Aula Regular</option>
            <option value="EDUCADORA_DIFERENCIAL">Rol: Educadora Diferencial (PIE)</option>
            <option value="JEFE_UTP">Rol: Jefe de UTP</option>
            <option value="COORDINADOR_PIE">Rol: Coordinador PIE</option>
            <option value="ADMIN_COLEGIO">Rol: Administrador del Colegio</option>
          </select>
          <span className="text-xs bg-emerald-900/60 border border-emerald-600/50 text-emerald-200 px-2.5 py-1 rounded-full">
            {autoSaveState === 'GUARDADO' ? '✓ Guardado automático' : 'Guardando...'}
          </span>
        </div>
      </header>

      <div className="flex-1 flex flex-col md:flex-row">
        <nav className="w-full md:w-64 bg-white border-r border-slate-200 p-4 space-y-1.5">
          {[
            { id: 'DASHBOARD', label: 'Panel Principal', icon: Filter },
            { id: 'PIE_MODULE', label: 'Gestión Estudiantes PIE', icon: ShieldCheck },
            { id: 'REFLEXION', label: 'Reflexión (3 Columnas)', icon: Sparkles }
          ].map(item => {
            const Icon = item.icon;
            return (
              <button key={item.id} onClick={() => setActiveModule(item.id as any)} className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-lg text-sm font-medium transition ${activeModule === item.id ? 'bg-indigo-50 text-indigo-900 border border-indigo-200' : 'text-slate-600 hover:bg-slate-100'}`}>
                <Icon className="w-4 h-4" /> {item.label}
              </button>
            );
          })}
        </nav>

        <main className="flex-1 p-6 max-w-6xl mx-auto w-full space-y-6">
          <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-wrap items-center justify-between gap-4">
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold uppercase tracking-wider text-indigo-700 bg-indigo-50 px-2.5 py-0.5 rounded">{planning.id}</span>
                <span className="text-xs font-semibold px-2.5 py-0.5 rounded bg-slate-100 text-slate-800">Estado: {planning.status}</span>
              </div>
              <h2 className="text-lg font-bold text-slate-900 mt-1">{planning.courseName} — {planning.subject}</h2>
            </div>
            <div className="flex items-center gap-2">
              {permissions.canCreateAndEditPlanning && planning.status === 'BORRADOR' && (
                <button onClick={handleSendToReview} className="inline-flex items-center gap-2 bg-indigo-700 hover:bg-indigo-800 text-white text-xs font-semibold px-4 py-2 rounded-lg shadow-sm">
                  <Send className="w-3.5 h-3.5" /> Enviar a Revisión
                </button>
              )}
            </div>
          </div>

          {activeModule === 'PIE_MODULE' && (
            <section className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm space-y-4">
              <h3 className="text-base font-bold text-slate-900 flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-indigo-700" /> Módulo Seguro PIE
              </h3>
              {activeRole === 'ADMIN_COLEGIO' || activeRole === 'JEFE_UTP' ? (
                <div className="p-4 bg-rose-50 border border-rose-200 rounded-lg text-rose-900 text-sm">
                  <strong>Acceso Restringido:</strong> El rol actual no posee acceso a antecedentes sensibles PIE.
                </div>
              ) : (
                <div className="space-y-3">
                  {planning.specificSupports.map(st => (
                    <div key={st.studentCode} className="p-4 rounded-lg border border-slate-200 bg-slate-50">
                      <span className="font-bold text-sm text-slate-900">Estudiante: {st.initials} — {st.supportType}</span>
                      <p className="text-xs text-slate-700 mt-2"><strong>Barreras:</strong> {st.barriers}</p>
                      <p className="text-xs text-slate-700 mt-1"><strong>Estrategias:</strong> {st.strategies}</p>
                    </div>
                  ))}
                </div>
              )}
            </section>
          )}

          {activeModule === 'REFLEXION' && (
            <section className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm space-y-4">
              <h3 className="text-base font-bold text-slate-900">Reflexión Pedagógica Post-Implementación</h3>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 rounded-xl border border-slate-200 bg-slate-50/60 space-y-3">
                  <div className="flex items-center justify-between">
                    <h4 className="text-sm font-bold text-indigo-950">A. Docente de Aula</h4>
                    {!permissions.canEditRegularReflection && <Lock className="w-4 h-4 text-slate-400" />}
                  </div>
                  <p className="text-xs text-slate-700"><strong>Estrategias:</strong> {planning.reflection.regularEffectiveStrategies}</p>
                </div>
                <div className="p-4 rounded-xl border border-slate-200 bg-slate-50/60 space-y-3">
                  <div className="flex items-center justify-between">
                    <h4 className="text-sm font-bold text-indigo-950">B. Educadora Diferencial</h4>
                    {!permissions.canEditSpecialReflection && <Lock className="w-4 h-4 text-slate-400" />}
                  </div>
                  <p className="text-xs text-slate-700"><strong>Estrategias:</strong> {planning.reflection.specialDiversifiedStrategies}</p>
                </div>
                <div className="p-4 rounded-xl border border-indigo-200 bg-indigo-50/40 space-y-3">
                  <div className="flex items-center justify-between">
                    <h4 className="text-sm font-bold text-indigo-950">C. Reflexión Conjunta</h4>
                    {!permissions.canEditJointReflection && <Lock className="w-4 h-4 text-slate-400" />}
                  </div>
                  <p className="text-xs text-slate-700"><strong>¿Qué funcionó bien?:</strong> {planning.reflection.jointWorkedWell}</p>
                </div>
              </div>
            </section>
          )}
        </main>
      </div>
    </div>
  );
}