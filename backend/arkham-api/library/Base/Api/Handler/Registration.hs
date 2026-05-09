module Base.Api.Handler.Registration where

import Import
import Network.HTTP.Types (status410)

postApiV1RegistrationR :: Handler Value
postApiV1RegistrationR =
  sendResponseStatus status410 $ object ["error" .= ("Registration is disabled" :: Text)]
