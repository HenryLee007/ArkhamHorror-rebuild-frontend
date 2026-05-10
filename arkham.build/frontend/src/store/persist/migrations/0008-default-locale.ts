import type { StoreState } from "@/store/slices";
import { DEFAULT_LOCALE } from "@/utils/constants";

function migrate(_state: unknown, version: number) {
  const state = _state as Partial<StoreState>;
  const shouldUseDefaultLocale =
    !state.settings?.locale || state.settings.locale === "en";

  if (version < 9 && shouldUseDefaultLocale) {
    state.settings = {
      ...state.settings,
      locale: DEFAULT_LOCALE,
    } as StoreState["settings"];

    delete state.metadata;
  }

  return state;
}

export default migrate;
