{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Base.Api.Handler.Admin.Users where

import Database.Persist qualified as P
import Database.Persist.Sql (fromSqlKey)
import Import
import Network.HTTP.Types (status400)

data AdminUserEntry = AdminUserEntry
  { id :: Int64
  , username :: Text
  , admin :: Bool
  }
  deriving stock (Generic)
  deriving anyclass (ToJSON)

data CreateUserRequest = CreateUserRequest
  { username :: Text
  }
  deriving stock (Generic)
  deriving anyclass (FromJSON)

toAdminUserEntry :: Entity User -> AdminUserEntry
toAdminUserEntry (Entity uid user) =
  AdminUserEntry
    { id = fromSqlKey uid
    , username = userUsername user
    , admin = userAdmin user
    }

getApiV1AdminUsersR :: Handler Value
getApiV1AdminUsersR = do
  users <- runDB $ selectList [] []
  pure $ toJSON $ map toAdminUserEntry users

postApiV1AdminUsersR :: Handler Value
postApiV1AdminUsersR = do
  CreateUserRequest {..} <- requireCheckJsonBody
  when (username == "") $ invalidArgs ["username must not be empty"]
  mExisting <- runDB $ P.getBy (UniqueUsername username)
  when (isJust mExisting) $ invalidArgs ["username already exists"]
  let user = User username Nothing Nothing False False
  uid <- runDB $ P.insert user
  pure $ toJSON $ toAdminUserEntry (Entity uid user)

deleteApiV1AdminUserR :: UserId -> Handler Value
deleteApiV1AdminUserR targetId = do
  currentUserId <- getRequestUserId
  when (currentUserId == targetId) $
    sendResponseStatus status400 $ object ["error" .= ("Cannot delete yourself" :: Text)]
  targetUser <- runDB $ P.get targetId
  case targetUser of
    Nothing -> notFound
    Just u -> do
      when (userAdmin u) $
        sendResponseStatus status400 $ object ["error" .= ("Cannot delete admin user" :: Text)]
      runDB $ P.delete targetId
      pure $ object ["success" .= True]
