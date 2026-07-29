export type UserRole =
  | 'admin'
  | 'coordinator'
  | 'manager'
  | 'inspector'
  | 'observer'
  | 'contractor';

export const getCurrentUserRoles = (): UserRole[] => {
  try {
    const token = localStorage.getItem('access_token');
    if (!token) return [];
    const payload = JSON.parse(atob(token.split('.')[1]));
    return payload.roles || [];
  } catch (error) {
    console.error('Ошибка получения ролей:', error);
    return [];
  }
};

export const hasAnyRole = (allowedRoles: UserRole[]): boolean => {
  const userRoles = getCurrentUserRoles();
  return userRoles.some(role => allowedRoles.includes(role));
};

export const canManageReferences = (): boolean => hasAnyRole(['admin']);
export const canManageUsers = (): boolean => hasAnyRole(['admin', 'manager']);
export const canManageAssignments = (): boolean => hasAnyRole(['admin', 'coordinator', 'manager']);
export const canCreateInspection = (): boolean => hasAnyRole(['admin', 'coordinator', 'manager', 'inspector']);
export const canEditAnyInspection = (): boolean => hasAnyRole(['admin', 'coordinator', 'manager']);
export const canViewAllInspections = (): boolean => hasAnyRole(['admin', 'coordinator', 'manager', 'inspector', 'observer']);
export const canApprovePlan = (): boolean => hasAnyRole(['coordinator', 'manager']);

export const getRoleDisplayName = (role: UserRole | string): string => {
  const names: Record<string, string> = {
    admin: 'Администратор',
    coordinator: 'Координатор',
    manager: 'Руководитель',
    inspector: 'Инспектор',
    observer: 'Наблюдатель',
    contractor: 'Подрядчик',
  };
  return names[role] || role;
};
