export interface UserData {
  id: string;
  email: string;
  full_name: string;
  is_active: boolean;
  roles: Array<{
    id: string;
    name: string;
    display_name: string;
  }>;
}