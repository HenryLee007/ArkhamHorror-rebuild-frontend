import i18n, { type LanguageDetectorModule } from "i18next";

import resourcesToBackend from "i18next-resources-to-backend";
import { initReactI18next } from "react-i18next";

import en from "@/locales/en.json";
import type { Locale } from "@/store/slices/settings.types";
import { DEFAULT_LOCALE, LOCALES } from "./constants";

const localStorageDectector: LanguageDetectorModule = {
  type: "languageDetector",
  detect() {
    if (typeof window === "undefined") return DEFAULT_LOCALE;
    const lang = localStorage.getItem("i18nextLng");
    return lang || DEFAULT_LOCALE;
  },
  cacheUserLanguage(lng: string) {
    if (typeof window === "undefined") return;
    localStorage.setItem("i18nextLng", lng);
  },
};

const importBackend = resourcesToBackend(
  async (lng: string, namespace: string) => {
    const bundle = await import(`@/locales/${lng}.json`);
    return bundle.default[namespace];
  },
);

i18n
  .use(localStorageDectector)
  .use(importBackend)
  .use(initReactI18next)
  .init({
    fallbackLng: "en",
    load: "currentOnly",
    partialBundledLanguages: true,
    showSupportNotice: false,
    supportedLngs: Object.keys(LOCALES),
    resources: {
      en,
    },
    interpolation: {
      escapeValue: false,
    },
  });

i18n.on("languageChanged", (lng) => {
  if (document) document.documentElement.lang = lng;
});

export function changeLanguage(lng: Locale) {
  if (i18n.language === lng) return;
  return i18n.changeLanguage(lng);
}

export default i18n;
