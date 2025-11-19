import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// タイムゾーンのヘルパー関数（JSTでの日付を取得）
const getJSTDate = (date: Date): string => {
  // 9時間のオフセット（ミリ秒）
  const jstOffset = 9 * 60 * 60 * 1000;
  const jstDate = new Date(date.getTime() + jstOffset);
  return jstDate.toISOString().split("T")[0]; // YYYY-MM-DD
};

// ---------------------------------------------------------
// 既存の関数: 投稿時のストリーク更新
// ---------------------------------------------------------
export const updateStreakOnPostCreate = onDocumentCreated(
  {
    document: "posts/{postId}",
    region: "asia-northeast1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.log("No data associated with the event.");
      return;
    }

    const post = snapshot.data();
    if (!post) {
      logger.log("投稿データがありません");
      return;
    }

    const uid = post.uid;
    const postCreatedAt = post.createdAt.toDate();

    // [注意] ここは既存のロジック通り 'user_profiles' を使用
    const userProfileRef = db.collection("user_profiles").doc(uid);

    try {
      await db.runTransaction(async (transaction) => {
        const userProfileDoc = await transaction.get(userProfileRef);
        if (!userProfileDoc.exists) {
          logger.log(`ユーザー(uid: ${uid})のプロフィールが見つかりません`);
          return;
        }

        const profileData = userProfileDoc.data();
        if (!profileData) return;

        const currentStreak: number = profileData.currentStreak ?? 0;
        const lastPostTimestamp: admin.firestore.Timestamp | undefined =
          profileData.lastPostDate;

        const todayJST = getJSTDate(postCreatedAt);

        if (!lastPostTimestamp) {
          logger.log("初めての投稿。ストリークを1に設定。");
          transaction.update(userProfileRef, {
            currentStreak: 1,
            lastPostDate: postCreatedAt,
          });
          return;
        }

        const lastPostDate = lastPostTimestamp.toDate();
        const lastPostDayJST = getJSTDate(lastPostDate);

        if (lastPostDayJST === todayJST) {
          logger.log("本日2回目以降の投稿。ストリークは変更なし。");
          transaction.update(userProfileRef, {
            lastPostDate: postCreatedAt,
          });
          return;
        }

        const yesterdayDate = new Date(
          postCreatedAt.getTime() - 24 * 60 * 60 * 1000
        );
        const yesterdayJST = getJSTDate(yesterdayDate);

        if (lastPostDayJST === yesterdayJST) {
          logger.log("連続投稿成功。ストリークをインクリメント。");
          transaction.update(userProfileRef, {
            currentStreak: currentStreak + 1,
            lastPostDate: postCreatedAt,
          });
        } else {
          logger.log("連続が途切れた。ストリークを1にリセット。");
          transaction.update(userProfileRef, {
            currentStreak: 1,
            lastPostDate: postCreatedAt,
          });
        }
      });
    } catch (error) {
      logger.error("ストリーク更新トランザクションに失敗しました:", error);
    }
    return;
  }
);

// ---------------------------------------------------------
// ▼▼▼ 新規追加: プッシュ通知送信関数 ▼▼▼
// ---------------------------------------------------------
export const sendPushNotification = onDocumentCreated(
  {
    document: "notifications/{notificationId}", // notificationsコレクションへの追加を検知
    region: "asia-northeast1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.log("No data associated with the event.");
      return;
    }

    const notification = snapshot.data();
    const targetUserId = notification.targetUserId; // 通知を送る相手のID

    // 自分のアクションによる通知なら送らない（念のため）
    if (notification.fromUserId === targetUserId) {
      return;
    }

    try {
      // 1. 通知先ユーザーのFCMトークンを取得
      // (Flutter側で 'users' コレクションに保存した 'fcmToken' を読みに行く)
      const userDoc = await db.collection("users").doc(targetUserId).get();

      if (!userDoc.exists) {
        logger.log(`User ${targetUserId} not found.`);
        return;
      }

      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;

      if (!fcmToken) {
        logger.log(`User ${targetUserId} has no FCM token registered.`);
        return;
      }

      // 2. 通知のメッセージ内容を作成
      let title = "MiniQuest 通知";
      let body = "新しいお知らせがあります";

      const senderName = notification.fromUserName || "誰か";

      switch (notification.type) {
        case "cheer":
          title = "🔥 応援が届きました！";
          body = `${senderName}さんがあなたのクエストを応援しています！`;
          break;
        case "comment":
          title = "💬 コメントがつきました";
          body = `${senderName}さんがコメントしました: "${
            notification.postTextSnippet || ""
          }"`;
          break;
        case "follow": // (もしあれば)
          title = "新しいフレンド";
          body = `${senderName}さんとフレンドになりました！`;
          break;
        default:
          break;
      }

      // 3. FCM経由で送信
      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          // アプリ側で受け取って画面遷移などに使うデータ
          type: notification.type,
          postId: notification.postId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        // iOS固有の設定
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      await admin.messaging().send(message);
      logger.log(`Successfully sent notification to user ${targetUserId}`);
    } catch (error) {
      logger.error("Error sending notification:", error);
    }
  }
);
