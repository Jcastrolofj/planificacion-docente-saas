export type UserRole =
  | 'ADMIN_COLEGIO'
  | 'DOCENTE_AULA'
  | 'EDUCADORA_DIFERENCIAL'
  | 'JEFE_UTP'
  | 'COORDINADOR_PIE';

export type PlanningStatus =
  | 'BORRADOR'
  | 'EN_REVISION'
  | 'SOLICITUD_AJUSTES'
  | 'REVISADO'
  | 'IMPLEMENTADO';

export type ReflectionStatus = 'PENDIENTE' | 'EN_ELABORACION' | 'COMPLETADA';

export type ReviewDecision = 'PENDIENTE' | 'OBSERVADO_SOLICITA_AJUSTES' | 'REVISADO_CONFORME';

export interface RolePermissionsMatrix {
  canConfigureInstitution: boolean;
  canManageUsersAndRoles: boolean;
  canAssignClassroomTeams: boolean;
  canEditCourseCharacterization: boolean;
  canManagePieStudentRecords: boolean;
  canCreateAndEditPlanning: boolean;
  canReviewAsUtp: boolean;
  canReviewAsPieCoordinator: boolean;
  canRegisterImplementation: boolean;
  canEditRegularReflection: boolean;
  canEditSpecialReflection: boolean;
  canEditJointReflection: boolean;
}

export const RBAC_PERMISSIONS: Record<UserRole, RolePermissionsMatrix> = {
  ADMIN_COLEGIO: {
    canConfigureInstitution: true,
    canManageUsersAndRoles: true,
    canAssignClassroomTeams: true,
    canEditCourseCharacterization: false,
    canManagePieStudentRecords: false, // Sin acceso irrestricto por defecto a datos sensibles PIE
    canCreateAndEditPlanning: false,
    canReviewAsUtp: false,
    canReviewAsPieCoordinator: false,
    canRegisterImplementation: false,
    canEditRegularReflection: false,
    canEditSpecialReflection: false,
    canEditJointReflection: false,
  },
  DOCENTE_AULA: {
    canConfigureInstitution: false,
    canManageUsersAndRoles: false,
    canAssignClassroomTeams: false,
    canEditCourseCharacterization: true,
    canManagePieStudentRecords: false,
    canCreateAndEditPlanning: true,
    canReviewAsUtp: false,
    canReviewAsPieCoordinator: false,
    canRegisterImplementation: true,
    canEditRegularReflection: true,
    canEditSpecialReflection: false,
    canEditJointReflection: true,
  },
  EDUCADORA_DIFERENCIAL: {
    canConfigureInstitution: false,
    canManageUsersAndRoles: false,
    canAssignClassroomTeams: false,
    canEditCourseCharacterization: true,
    canManagePieStudentRecords: true,
    canCreateAndEditPlanning: true,
    canReviewAsUtp: false,
    canReviewAsPieCoordinator: false,
    canRegisterImplementation: true,
    canEditRegularReflection: false,
    canEditSpecialReflection: true,
    canEditJointReflection: true,
  },
  JEFE_UTP: {
    canConfigureInstitution: false,
    canManageUsersAndRoles: false,
    canAssignClassroomTeams: false,
    canEditCourseCharacterization: false,
    canManagePieStudentRecords: false, // Sin acceso innecesario a registros sensibles individuales PIE
    canCreateAndEditPlanning: false,
    canReviewAsUtp: true,
    canReviewAsPieCoordinator: false,
    canRegisterImplementation: false,
    canEditRegularReflection: false,
    canEditSpecialReflection: false,
    canEditJointReflection: false,
  },
  COORDINADOR_PIE: {
    canConfigureInstitution: false,
    canManageUsersAndRoles: false,
    canAssignClassroomTeams: false,
    canEditCourseCharacterization: false,
    canManagePieStudentRecords: true,
    canCreateAndEditPlanning: false,
    canReviewAsUtp: false,
    canReviewAsPieCoordinator: true,
    canRegisterImplementation: false,
    canEditRegularReflection: false,
    canEditSpecialReflection: false,
    canEditJointReflection: false,
  },
};
