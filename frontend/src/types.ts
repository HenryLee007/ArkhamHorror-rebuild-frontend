export interface User {
  username: string;
  email?: string;
  beta: boolean;
  admin: boolean;
}

export interface Authentication {
  token: string;
}

export interface Credentials {
  username: string;
  password?: string;
}
