import axios from 'axios';

const host = import.meta.env.VITE_API_HOST || '';
const api = axios.create({
  baseURL: `${host}/api/v1`,
  headers: {
    'Content-Type': 'application/json',
  },
});

export interface AdminUser {
  id: number;
  username: string;
  admin: boolean;
}

export function fetchAdminUsers() {
  return api.get<AdminUser[]>('admin/users');
}

export function createAdminUser(username: string) {
  return api.post<AdminUser>('admin/users', { username });
}

export function deleteAdminUser(userId: number) {
  return api.delete(`admin/users/${userId}`);
}

export default api;
