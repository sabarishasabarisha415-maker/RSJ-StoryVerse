const assert = require('node:assert/strict');

const projectId = 'demo-rsj-storyverse';
const firestoreResource = `projects/${projectId}/databases/(default)`;
const firestoreBase = `http://127.0.0.1:8080/v1/${firestoreResource}`;
const authBase = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';

async function request(url, { method = 'GET', body, token } = {}) {
  const headers = {};
  if (body) headers['Content-Type'] = 'application/json';
  if (token) headers.Authorization = `Bearer ${token}`;

  return fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
}

async function createUser(label) {
  const response = await request(
    `${authBase}/accounts:signUp?key=fake-api-key`,
    {
      method: 'POST',
      body: {
        email: `${label}-${Date.now()}@example.test`,
        password: 'test-password-123',
        returnSecureToken: true,
      },
    },
  );
  if (response.status !== 200) {
    throw new Error(`Auth emulator failed to create a test user: ${await response.text()}`);
  }
  return response.json();
}

async function createAnonymousUser() {
  const response = await request(
    `${authBase}/accounts:signUp?key=fake-api-key`,
    {
      method: 'POST',
      body: { returnSecureToken: true },
    },
  );
  if (response.status !== 200) {
    throw new Error(
      `Auth emulator failed to create an anonymous user: ${await response.text()}`,
    );
  }
  return response.json();
}

function storyFields(
  authorId,
  status,
  storyContent = 'Emulator-only test fixture.',
) {
  return {
    title: { stringValue: `Emulator ${status} story ${storyContent}` },
    author: { stringValue: 'Emulator Test Author' },
    authorId: { stringValue: authorId },
    genre: { stringValue: 'Test' },
    description: { stringValue: '' },
    story: { stringValue: storyContent },
    coverUrl: { stringValue: '' },
    coverStoragePath: { stringValue: '' },
    status: { stringValue: status },
  };
}

function queryPublishedStories(token) {
  return runQuery(
    'documents:runQuery',
    {
      from: [{ collectionId: 'stories' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'status' },
          op: 'EQUAL',
          value: { stringValue: 'published' },
        },
      },
    },
    token,
  );
}

function runQuery(parentPath, structuredQuery, token) {
  return request(`${firestoreBase}/${parentPath}`, {
    method: 'POST',
    token,
    body: { structuredQuery },
  });
}

async function writeDocument(path, fields, token, transforms = []) {
  const update = {
    name: `${firestoreResource}/documents/${path}`,
    fields,
  };
  const write = { update };
  if (transforms.length > 0) write.updateTransforms = transforms;
  return request(`${firestoreBase}/documents:commit`, {
    method: 'POST',
    token,
    body: { writes: [write] },
  });
}

async function updateDocument(path, fields, fieldPaths, token, transforms = []) {
  const update = {
    name: `${firestoreResource}/documents/${path}`,
    fields,
  };
  const write = { update, updateMask: { fieldPaths } };
  if (transforms.length > 0) write.updateTransforms = transforms;
  return request(`${firestoreBase}/documents:commit`, {
    method: 'POST',
    token,
    body: { writes: [write] },
  });
}

async function main() {
  const [userA, userB, anonymousAuthor] = await Promise.all([
    createUser('owner'),
    createUser('reader'),
    createAnonymousUser(),
  ]);
  const draftPath = 'stories/private-draft';
  const publicPath = 'stories/public-story';

  let response = await queryPublishedStories();
  assert.equal(response.status, 403, 'Signed-out users must not query stories');

  response = await queryPublishedStories(anonymousAuthor.idToken);
  assert.equal(response.status, 403, 'Anonymous users must not query stories');

  response = await queryPublishedStories(userA.idToken);
  assert.equal(response.status, 200, 'Email-authenticated empty feed query should succeed');
  const emptyFeed = await response.json();
  assert.equal(
    emptyFeed.some((result) => result.document),
    false,
    'An empty database returns no stories',
  );

  response = await request(`${firestoreBase}/documents/stories/missing-story`, {
    token: userA.idToken,
  });
  assert.equal(response.status, 404, 'Authenticated missing-story lookup should return not found');

  response = await writeDocument(
    draftPath,
    storyFields(userA.localId, 'draft'),
    userA.idToken,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 200, await response.text());

  response = await runQuery(
    'documents:runQuery',
    {
      from: [{ collectionId: 'stories' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'authorId' },
          op: 'EQUAL',
          value: { stringValue: userA.localId },
        },
      },
    },
    userA.idToken,
  );
  assert.equal(response.status, 200, 'Authors should query their own stories');

  response = await request(`${firestoreBase}/documents/${draftPath}`, {
    token: userA.idToken,
  });
  assert.equal(response.status, 200, 'Owner should be able to read a draft');

  response = await request(`${firestoreBase}/documents/${draftPath}`, {
    token: userB.idToken,
  });
  assert.equal(response.status, 200, 'Any authenticated user must read any story');

  response = await request(`${firestoreBase}/documents/${draftPath}`);
  assert.equal(response.status, 403, 'Unauthenticated readers must not read drafts');

  response = await request(`${firestoreBase}/documents/${draftPath}`, {
    token: anonymousAuthor.idToken,
  });
  assert.equal(response.status, 403, 'Anonymous users must not read drafts');

  response = await writeDocument(
    draftPath,
    storyFields(userB.localId, 'published'),
    userB.idToken,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 403, 'Another user must not edit the draft');

  response = await writeDocument(
    'stories/forged-owner',
    storyFields(userA.localId, 'published'),
    userB.idToken,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 403, 'Users must not create stories for others');

  response = await writeDocument(
    publicPath,
    storyFields(userA.localId, 'published', 'Alpha content'),
    userA.idToken,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 200, await response.text());

  response = await request(`${firestoreBase}/documents/${publicPath}`);
  assert.equal(response.status, 403, 'Signed-out users must not read published stories');

  response = await request(`${firestoreBase}/documents/${publicPath}`, {
    token: userB.idToken,
  });
  assert.equal(response.status, 200, 'Email-authenticated users can read other users stories');
  const alphaStory = await response.json();
  assert.equal(
    alphaStory.fields.story.stringValue,
    'Alpha content',
    'The selected story document supplies its own content',
  );

  response = await queryPublishedStories(userB.idToken);
  assert.equal(response.status, 200, 'Email-authenticated story queries should be allowed');

  response = await request(`${firestoreBase}/documents:runQuery`, {
    method: 'POST',
    body: { structuredQuery: { from: [{ collectionId: 'stories' }] } },
  });
  assert.equal(response.status, 403, 'Unauthenticated story queries must be denied');

  response = await runQuery(
    'documents:runQuery',
    { from: [{ collectionId: 'stories' }] },
    userB.idToken,
  );
  assert.equal(response.status, 200, 'Authenticated users can query every story');

  response = await writeDocument(
    'stories/unauthenticated-write',
    storyFields('unverified-author', 'published'),
    undefined,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 403, 'Unauthenticated story writes must be denied');

  const anonymousStoryPath = 'stories/anonymous-public-story';
  response = await writeDocument(
    anonymousStoryPath,
    storyFields(anonymousAuthor.localId, 'published'),
    anonymousAuthor.idToken,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 403, 'Anonymous users must not publish stories');

  response = await request(`${firestoreBase}/documents/${anonymousStoryPath}`);
  assert.equal(response.status, 403, 'Anonymous users cannot read or create stories');

  response = await request(`${firestoreBase}/documents/${publicPath}`, {
    token: anonymousAuthor.idToken,
  });
  assert.equal(response.status, 403, 'Anonymous users must not read published stories');

  const likePath = `${publicPath}/likes/${userB.localId}`;
  response = await writeDocument(
    likePath,
    { uid: { stringValue: userB.localId } },
    userB.idToken,
    [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
  );
  assert.equal(response.status, 200, 'Authenticated readers can like another users story');

  response = await request(`${firestoreBase}/documents/${likePath}`, {
    token: userA.idToken,
  });
  assert.equal(response.status, 200, 'All authenticated readers can view story likes');

  response = await runQuery(
    'documents/stories/public-story:runQuery',
    { from: [{ collectionId: 'likes' }] },
    userA.idToken,
  );
  assert.equal(response.status, 200, 'Authenticated readers can query story likes');

  response = await request(`${firestoreBase}/documents:commit`, {
    method: 'POST',
    token: userA.idToken,
    body: {
      writes: [{ delete: `${firestoreResource}/documents/${likePath}` }],
    },
  });
  assert.equal(response.status, 403, 'A user cannot remove another users like');

  response = await request(`${firestoreBase}/documents:commit`, {
    method: 'POST',
    token: userB.idToken,
    body: {
      writes: [{ delete: `${firestoreResource}/documents/${likePath}` }],
    },
  });
  assert.equal(response.status, 200, 'Users can remove their own likes');

  response = await writeDocument(
    `${publicPath}/likes/${anonymousAuthor.localId}`,
    { uid: { stringValue: anonymousAuthor.localId } },
    anonymousAuthor.idToken,
    [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
  );
  assert.equal(response.status, 403, 'Anonymous users cannot like stories');

  const commentPath = `${publicPath}/comments/user-b-comment`;
  const commentFields = {
    uid: { stringValue: userB.localId },
    author: { stringValue: 'Reader B' },
    text: { stringValue: 'A helpful comment.' },
  };
  response = await writeDocument(
    commentPath,
    commentFields,
    userB.idToken,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 200, 'Authenticated readers can comment on stories');

  response = await request(`${firestoreBase}/documents/${commentPath}`, {
    token: userA.idToken,
  });
  assert.equal(response.status, 200, 'All authenticated readers can view comments');

  response = await runQuery(
    'documents/stories/public-story:runQuery',
    { from: [{ collectionId: 'comments' }] },
    userA.idToken,
  );
  assert.equal(response.status, 200, 'Authenticated readers can query story comments');

  response = await updateDocument(
    commentPath,
    { text: { stringValue: 'Edited by the wrong user.' } },
    ['text', 'updatedAt'],
    userA.idToken,
    [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
  );
  assert.equal(response.status, 403, 'A user cannot edit another users comment');

  response = await updateDocument(
    commentPath,
    { text: { stringValue: 'Edited by its author.' } },
    ['text', 'updatedAt'],
    userB.idToken,
    [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
  );
  assert.equal(response.status, 200, 'Comment authors can edit their own comments');

  response = await request(`${firestoreBase}/documents:commit`, {
    method: 'POST',
    token: userA.idToken,
    body: {
      writes: [{ delete: `${firestoreResource}/documents/${commentPath}` }],
    },
  });
  assert.equal(response.status, 403, 'A user cannot delete another users comment');

  response = await request(`${firestoreBase}/documents:commit`, {
    method: 'POST',
    token: userB.idToken,
    body: {
      writes: [{ delete: `${firestoreResource}/documents/${commentPath}` }],
    },
  });
  assert.equal(response.status, 200, 'Comment authors can delete their own comments');

  response = await writeDocument(
    `${publicPath}/likes/${userA.localId}`,
    { uid: { stringValue: userA.localId } },
    undefined,
    [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
  );
  assert.equal(response.status, 403, 'Unauthenticated users cannot like stories');

  response = await writeDocument(
    `${publicPath}/comments/unauthenticated-comment`,
    {
      uid: { stringValue: userA.localId },
      author: { stringValue: 'Guest' },
      text: { stringValue: 'Unauthenticated comment.' },
    },
    undefined,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 403, 'Unauthenticated users cannot comment on stories');

  response = await writeDocument(
    `${publicPath}/comments/anonymous-comment`,
    {
      uid: { stringValue: anonymousAuthor.localId },
      author: { stringValue: 'Anonymous' },
      text: { stringValue: 'Anonymous comment.' },
    },
    anonymousAuthor.idToken,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 403, 'Anonymous users cannot comment on stories');

  const userBStoryPath = 'stories/user-b-story';
  response = await writeDocument(
    userBStoryPath,
    storyFields(userB.localId, 'published', 'Beta content'),
    userB.idToken,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 200, 'Email-authenticated users can create stories');

  response = await request(`${firestoreBase}/documents/${userBStoryPath}`, {
    token: userA.idToken,
  });
  assert.equal(response.status, 200, 'Another authenticated user can read the second story');
  const betaStory = await response.json();
  assert.equal(
    betaStory.fields.story.stringValue,
    'Beta content',
    'A different story ID resolves to its corresponding content',
  );

  response = await writeDocument(
    userBStoryPath,
    storyFields(userA.localId, 'published'),
    userA.idToken,
  );
  assert.equal(response.status, 403, 'Another email user cannot edit a story');

  response = await request(`${firestoreBase}/documents:commit`, {
    method: 'POST',
    token: userA.idToken,
    body: {
      writes: [{ delete: `${firestoreResource}/documents/${userBStoryPath}` }],
    },
  });
  assert.equal(response.status, 403, 'Another email user cannot delete a story');

  response = await writeDocument(
    userBStoryPath,
    storyFields(userB.localId, 'published'),
    userB.idToken,
    [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ],
  );
  assert.equal(response.status, 200, 'Story owners can edit their stories');

  response = await request(`${firestoreBase}/documents:commit`, {
    method: 'POST',
    token: userB.idToken,
    body: {
      writes: [{ delete: `${firestoreResource}/documents/${userBStoryPath}` }],
    },
  });
  assert.equal(response.status, 200, 'Story owners can delete their stories');

  const historyPath = `users/${userA.localId}/reading_history/${publicPath.split('/').pop()}`;
  response = await writeDocument(
    historyPath,
    {
      storyId: { stringValue: 'public-story' },
      title: { stringValue: 'Emulator published story' },
      author: { stringValue: 'Emulator Test Author' },
      genre: { stringValue: 'Test' },
      coverUrl: { stringValue: '' },
      authorId: { stringValue: userA.localId },
      lastReadChapter: { stringValue: 'Chapter 1' },
      progress: { integerValue: '0' },
    },
    userA.idToken,
    [{ fieldPath: 'lastReadTime', setToServerValue: 'REQUEST_TIME' }],
  );
  assert.equal(response.status, 200, await response.text());

  response = await request(`${firestoreBase}/documents/${historyPath}`, {
    token: userA.idToken,
  });
  assert.equal(response.status, 200, 'Owner should be able to read reading history');

  response = await request(`${firestoreBase}/documents/${historyPath}`, {
    token: userB.idToken,
  });
  assert.equal(response.status, 403, 'Another user must not read reading history');

  response = await request(`${firestoreBase}/documents/${historyPath}`, {
    token: anonymousAuthor.idToken,
  });
  assert.equal(response.status, 403, 'Anonymous users must not read reading history');

  const readingHistoryQuery = {
    from: [{ collectionId: 'reading_history' }],
    orderBy: [
      {
        field: { fieldPath: 'lastReadTime' },
        direction: 'DESCENDING',
      },
    ],
  };
  response = await runQuery(
    `documents/users/${userA.localId}:runQuery`,
    readingHistoryQuery,
    userA.idToken,
  );
  assert.equal(response.status, 200, 'Owner should query reading history');
  response = await runQuery(
    `documents/users/${userA.localId}:runQuery`,
    readingHistoryQuery,
    userB.idToken,
  );
  assert.equal(response.status, 403, 'Other users must not query reading history');

  const profilePath = `users/${userA.localId}`;
  response = await writeDocument(
    profilePath,
    {
      displayName: { stringValue: 'Emulator Test User' },
      email: { stringValue: 'emulator@example.test' },
      bio: { stringValue: 'Private emulator profile.' },
    },
    userA.idToken,
  );
  assert.equal(response.status, 200, await response.text());

  response = await request(`${firestoreBase}/documents/${profilePath}`, {
    token: userB.idToken,
  });
  assert.equal(response.status, 403, 'Another user must not read a private profile');

  response = await request(`${firestoreBase}/documents/${profilePath}`, {
    token: anonymousAuthor.idToken,
  });
  assert.equal(response.status, 403, 'Anonymous users must not read a private profile');

  const favoritePath = `favorites/${userA.localId}_public-story`;
  response = await writeDocument(
    favoritePath,
    {
      uid: { stringValue: userA.localId },
      storyId: { stringValue: 'public-story' },
      title: { stringValue: 'Emulator published story' },
      author: { stringValue: 'Emulator Test Author' },
      genre: { stringValue: 'Test' },
      story: { stringValue: 'Emulator-only test fixture.' },
      coverUrl: { stringValue: '' },
    },
    userA.idToken,
    [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
  );
  assert.equal(response.status, 200, await response.text());

  response = await request(`${firestoreBase}/documents/${favoritePath}`, {
    token: userA.idToken,
  });
  assert.equal(response.status, 200, 'Owner should be able to read favorites');

  response = await request(`${firestoreBase}/documents/${favoritePath}`, {
    token: userB.idToken,
  });
  assert.equal(response.status, 403, 'Another user must not read favorites');

  response = await request(`${firestoreBase}/documents/${favoritePath}`, {
    token: anonymousAuthor.idToken,
  });
  assert.equal(response.status, 403, 'Anonymous users must not read favorites');

  const favoritesQuery = {
    from: [{ collectionId: 'favorites' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'uid' },
        op: 'EQUAL',
        value: { stringValue: userA.localId },
      },
    },
  };
  response = await runQuery(
    'documents:runQuery',
    favoritesQuery,
    userA.idToken,
  );
  assert.equal(response.status, 200, 'Owner should query favorites');
  response = await runQuery(
    'documents:runQuery',
    favoritesQuery,
    userB.idToken,
  );
  assert.equal(response.status, 403, 'Other users must not query favorites');

  console.log('Firestore authentication, ownership, likes, and comments checks passed.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
