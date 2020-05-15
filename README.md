# Implementing middleware

To use the Express endpoint, replace `function`
value with `api` in `firebase.json` on root folder.

```json
  "hosting": {
    "public": "public",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "/api/**",
        "function": "api"
      }
    ]
  }
```

# Startup code

Example code on `functions/src/index.ts`:

```javascript
import * as _functions from "firebase-functions";
import * as _admin from "firebase-admin";
import * as _express from "express";
import { FirebaseAuthMiddleware } from "./frameworks/firebase_auth_middleware";
import { UserQueries } from "./endpoints/queries/user-queries";
import { PostTriggers } from "./endpoints/triggers/post-triggers";

// Used for the token authorization.
const _cookieParser = require("cookie-parser")();
const _cors = require("cors")({ origin: true });

// Constant variables.
const _DATABASE_URL = "https://yourdatabase.firebaseio.com";
const _PRIVATE_KEY_PATH = "../private-key.json";

// Initiliaze express.
const _app = _express();

// Initialize the bearer authentication.
const serviceAccount = require(_PRIVATE_KEY_PATH);
_admin.initializeApp({
  credential: _admin.credential.cert(serviceAccount),
  databaseURL: _DATABASE_URL,
});

// Initialize the express framework.
_app.use(_express.json());
_app.use(_cors);
_app.options("*", _cors);
_app.use(_cookieParser);
_app.use(FirebaseAuthMiddleware.validateIdToken); // Authorization: Bearer <your-client-token>

/* -------------------------------------------------------------------------- */
/*                      Express HTTPS end point functions                     */
/* -------------------------------------------------------------------------- */

_app.get("/random-name", UserQueries.getRandomName);

/* -------------------------------------------------------------------------- */
/*                              Trigger functions                             */
/* -------------------------------------------------------------------------- */

exports.on_post_delete = PostTriggers.onDelete;

/* -------------------------------------------------------------------------- */
/*                        Don't do anything below this                        */
/* -------------------------------------------------------------------------- */

/**
 * Apply the condition based on the cors, cookie parser
 * and the token validation for the express API.
 * IMPORTANT: This call must be at the bottom.
 */
exports.api = _functions.https.onRequest(_app);
```
