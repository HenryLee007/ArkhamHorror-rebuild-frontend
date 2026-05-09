module Base.Api.Handler.PasswordReset (postApiV1PasswordResetsR, putApiV1PasswordResetR) where

import Import
import Network.HTTP.Types (status410)

postApiV1PasswordResetsR :: Handler Value
postApiV1PasswordResetsR =
  sendResponseStatus status410 $ object ["error" .= ("Password reset is disabled" :: Text)]

putApiV1PasswordResetR :: PasswordResetId -> Handler Value
putApiV1PasswordResetR _ =
  sendResponseStatus status410 $ object ["error" .= ("Password reset is disabled" :: Text)]
