import CampaignLog from '@/arkham/views/CampaignLog.vue';
import Game from '@/arkham/views/Game.vue';
import Deck from '@/arkham/views/Deck.vue';
import Decks from '@/arkham/views/Decks.vue';
import ArkhamBuildImport from '@/arkham/views/ArkhamBuildImport.vue';
import JoinGame from '@/arkham/views/JoinGame.vue';
import ClaimSeat from '@/arkham/views/ClaimSeat.vue';
import ReplayGame from '@/arkham/views/ReplayGame.vue';
import NewCampaign from '@/arkham/views/NewCampaign.vue';
import { RouteLocationNormalized } from 'vue-router';

const ArkhamBuildRedirect = { template: '<div />' }

export default [
  {
    path: '/cards',
    name: 'Cards',
    component: ArkhamBuildRedirect,
    beforeEnter: () => {
      window.location.assign('/build/browse')
      return false
    },
    meta: { requiresAuth: true, title: "Arkham Horror: Cards" },
    props: true,
  },
  {
    path: '/decks/import/arkham-build',
    name: 'ArkhamBuildImport',
    component: ArkhamBuildImport,
    meta: { requiresAuth: true, title: "Arkham Horror: Import Deck" },
    props: true,
  },
  {
    path: '/deck/:deckId',
    name: 'Deck',
    component: Deck,
    meta: { requiresAuth: true, title: "Arkham Horror: Deck" },
    props: true,
  },
  {
    path: '/decks',
    name: 'Decks',
    component: Decks,
    meta: { requiresAuth: true, title: "Arkham Horror: 我的牌组" },
    props: true,
  },
  {
    path: '/campaigns/new',
    name: 'NewCampaign',
    component: NewCampaign,
    meta: { requiresAuth: true, title: "Arkham Horror: New Game" },
    props: true,
  },
  {
    path: '/games/:gameId',
    name: 'Game',
    component: Game,
    meta: { requiresAuth: true, title: "Arkham Horror" },
    props: true,
  },
  {
    path: '/admin/games/:gameId',
    name: 'AdminGame',
    component: Game,
    meta: { requiresAuth: true, title: "Arkham Horror" },
    props: (route: RouteLocationNormalized) => ({ ...route.params, spectate: true }),
  },
  {
    path: '/games/:gameId/spectate',
    name: 'Spectate',
    component: Game,
    meta: { requiresAuth: true, title: "Arkham Horror: Spectate" },
    props: (route: RouteLocationNormalized) => ({ ...route.params, spectate: true }),
  },
  {
    path: '/games/:gameId/log',
    name: 'CampaignLog',
    component: CampaignLog,
    meta: { requiresAuth: true, title: "Arkham Horror: Campaign Log" },
    props: true,
  },
  {
    path: '/games/:gameId/join',
    name: 'JoinGame',
    component: JoinGame,
    meta: { requiresAuth: true, title: "Arkham Horror: Join Game" },
    props: true,
  },
  {
    path: '/games/:gameId/claim-seat',
    name: 'ClaimSeat',
    component: ClaimSeat,
    meta: { requiresAuth: true, title: "Arkham Horror: Claim Seat" },
    props: true,
  },
  {
    path: '/games/:gameId/replay',
    name: 'ReplayGame',
    component: ReplayGame,
    meta: { requiresAuth: true, title: "Arkham Horror: Replay" },
    props: true,
  },
];
