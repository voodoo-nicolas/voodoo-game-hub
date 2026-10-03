// session-finish Edge Function entry point; the logic is in handler.ts.
import { serve } from "../_shared/http.ts";
import handler from "./handler.ts";

serve(handler);
