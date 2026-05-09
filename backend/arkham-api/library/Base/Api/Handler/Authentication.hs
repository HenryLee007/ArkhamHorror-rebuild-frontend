module Base.Api.Handler.Authentication where

import Crypto.BCrypt
import Data.Text.Encoding qualified as TE
import Import
import Network.HTTP.Types (status401)
import Types

postApiV1AuthenticationR :: Handler Token
postApiV1AuthenticationR = do
  AuthenticationRequest {..} <- requireCheckJsonBody
  muser <- runDB $ getBy (UniqueUsername authUsername)
  case muser of
    Nothing -> notAuthenticated
    Just (Entity userId user)
      | userAdmin user -> do
          -- Admin must provide password
          password <- maybe (sendResponseStatus status401 $ object ["error" .= ("管理员需要输入密码" :: Text)]) pure authPassword
          case userPasswordDigest user of
            Nothing -> notAuthenticated
            Just digest ->
              if validatePassword (TE.encodeUtf8 digest) (TE.encodeUtf8 password)
                then Token <$> userIdToToken userId
                else notAuthenticated
      | otherwise ->
          -- Non-admin users log in without password
          Token <$> userIdToToken userId
