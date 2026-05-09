import { createApp } from 'vue'
import { createPinia } from 'pinia'
import FloatingVue from 'floating-vue'
import Toast from "vue-toastification";
import { createVfm } from 'vue-final-modal'
import "vue-toastification/dist/index.css";
import 'vue-final-modal/style.css'
import App from './App.vue'
import router from './router'
import { FontAwesomeIcon } from "@fortawesome/vue-fontawesome";
import { library } from "@fortawesome/fontawesome-svg-core";
import { faExpeditedssl } from "@fortawesome/free-brands-svg-icons";
import { faBan, faCircleExclamation, faGhost, faLocationDot, faSearch, faList, faImage, faAngleDown, faUndo, faTrash, faEye, faCopy, faExternalLink, faRefresh, faBook, faChevronRight, faBars, faTimes, faShieldHeart } from '@fortawesome/free-solid-svg-icons'
import * as VueI18n from 'vue-i18n'
import messages from '@/locales/messages'
import mitt from 'mitt';

const supportedLanguages = ['en', 'zh'] as const
type SupportedLanguage = typeof supportedLanguages[number]

const isSupportedLanguage = (value: string): value is SupportedLanguage =>
  supportedLanguages.includes(value as SupportedLanguage)

const normalizeLanguage = (value?: string | null): SupportedLanguage => {
  const languageCode = value?.split('-')[0]
  return languageCode && isSupportedLanguage(languageCode) ? languageCode : 'en'
}

const language = localStorage.getItem('language')
const currentLanguage = normalizeLanguage(language ?? navigator.language)
if (language !== currentLanguage) { localStorage.setItem('language', currentLanguage) }

const i18n = VueI18n.createI18n({
  locale: currentLanguage, // set locale
  fallbackLocale: 'en', // set fallback locale
  legacy: false,
  warnHtmlMessage: false,
  messages
})

library.add(faBan, faLocationDot, faCircleExclamation, faGhost, faSearch, faList, faImage, faAngleDown, faExpeditedssl, faUndo, faTrash, faEye, faCopy, faExternalLink, faRefresh, faBook, faChevronRight, faBars, faTimes, faShieldHeart)

const pinia = createPinia()
const vfm = createVfm()
const emitter = mitt()

const app = createApp(App).
  use(router).
  use(pinia).
  use(FloatingVue).
  use(Toast, {}).
  use(vfm).
  use(i18n).
  component("font-awesome-icon", FontAwesomeIcon)

app.config.globalProperties.emitter = emitter

app.mount('#app')
