# Indie Inbox

A hosted solution for adding just the right amount of functionality to an existing Indieweb site (like a personal blog on its own domain) to create a functional and interactive ActivityPub server.

The idea is that you are responsible for all the static, read-only stuff that ActivityPub requires, and then you use this service to manage the collections that can be modified by others—your inbox, followers, and following—while also handling delivery of your outbox activities.

## 1. Listening for follows

This service needs to know who's subscribed. When a follow request comes in, it is accepted and stored for later use. (Unfollows work the same way, but in reverse.) All of this is transparent to you.

### 1a. Following others

If you publish a Follow activity in your outbox, this service will listen for an Accept activity after delivering that Follow and update your Following collection for you.

## 2. Broadcasting new activity

When this service is made aware of an update to your outbox, it will deliver the new activities to your followers. You can tell the service to check your outbox by sending a `PUT` request to your managed actor URL.

## 3. Checking your messages

When you create an account with Indie Inbox, you are given an auth token that will allow you to send GET requests to your inbox. With this you can see anything that's been sent to you.

# Limitations

1. Since your feed is public, your posts are public. You can choose specific audiences for each activity, but your outbox is read by this service in the same way that anyone else on the web can read it. Perhaps someday there will be support for authorization, but I think that adding ACL to your outbox is out of scope for a statically-served personal blog, which is the primary use case for this server.
