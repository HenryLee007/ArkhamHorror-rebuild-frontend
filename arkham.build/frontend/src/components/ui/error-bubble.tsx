import { CircleAlertIcon } from "lucide-react";
import css from "./error-bubble.module.css";

export function ErrorBubble() {
  return (
    <div className={css["error-bubble"]}>
      <CircleAlertIcon />
    </div>
  );
}
