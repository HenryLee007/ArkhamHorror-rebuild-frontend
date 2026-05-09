import Home from '@/views/Home.vue';
import SignIn from '@/views/SignIn.vue';
import Settings from '@/views/Settings.vue';
import About from '@/views/About.vue';
import Admin from '@/views/Admin.vue';
import AdminUsers from '@/views/AdminUsers.vue';
import Rooms from '@/views/Rooms.vue';

export default [
  {
    path: '/',
    name: 'Home',
    component: Home,
    meta: { requiresAuth: true, title: "Arkham Horror" },
  },
  {
    path: '/new-game',
    name: 'NewGame',
    component: Home,
    meta: { requiresAuth: true, title: "Arkham Horror" },
  },
  {
    path: '/settings',
    name: 'Settings',
    component: Settings,
    meta: { requiresAuth: true, title: "Arkham Horror: Settings" },
  },
  {
    path: '/about',
    name: 'About',
    component: About,
    meta: { requiresAuth: false, title: "Arkham Horror: About" },
  },
  {
    path: '/admin',
    name: 'Admin',
    component: Admin,
    meta: { requiresAuth: true, requiresAdmin: true, title: "Arkham Horror: Admin" },
  },
  {
    path: '/admin/users',
    name: 'AdminUsers',
    component: AdminUsers,
    meta: { requiresAuth: true, requiresAdmin: true, title: "Arkham Horror: Users" },
  },
  {
    path: '/admin/rooms',
    name: 'Rooms',
    component: Rooms,
    meta: { requiresAuth: true, requiresAdmin: true, title: "Arkham Horror: Rooms" },
  },
  {
    path: '/sign-in',
    name: 'SignIn',
    component: SignIn,
    meta: { guest: true, title: "ArkhamHorror: Sign in" },
  },
];
