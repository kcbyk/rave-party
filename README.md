# Party Rave

Private watch-party rooms with friend requests, accepted room invitations, synchronized playback, chat, and peer-to-peer WebRTC voice.

## Run the backend

```powershell
cd backend
npm ci
npm start
```

The server stores users, friend requests, room invitations, and rooms in `backend/data/party-rave.json`. Set `DATA_FILE` to use a managed persistent volume in production. Set `CORS_ORIGIN` to the deployed app origin.

## Run the app

The default server addresses are for a simulator/local development only. For two real phones, deploy the backend with HTTPS and launch each app with its public URL:

```powershell
flutter run --dart-define=SERVER_URL=https://your-api.example.com
```

Voice is WebRTC audio. It uses a public STUN server for development. Add your own authenticated TURN server before production so calls also work behind restrictive NATs.

## Flow

1. Both people open the app and their profile syncs.
2. Search a user and send a friend request; the recipient accepts it.
3. The host creates a room and sends a room invitation to a friend.
4. The recipient accepts the room invitation, opens that room, and joins voice and playback synchronization.

`flutter analyze` and `flutter test` are the local verification commands.
