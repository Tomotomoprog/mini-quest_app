// functions/src/index.ts
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler"; // 追加: スケジュール実行用
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// タイムゾーンのヘルパー関数
const getJSTDate = (date: Date): string => {
  const jstOffset = 9 * 60 * 60 * 1000;
  const jstDate = new Date(date.getTime() + jstOffset);
  return jstDate.toISOString().split("T")[0]; // YYYY-MM-DD
};

// ---------------------------------------------------------
// 1. 投稿時のストリーク更新 & 通知 (既存)
// ---------------------------------------------------------
export const updateStreakOnPostCreate = onDocumentCreated(
  {
    document: "posts/{postId}",
    region: "asia-northeast1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const post = snapshot.data();
    const uid = post.uid;
    const postCreatedAt = post.createdAt.toDate();
    const userProfileRef = db.collection("users").doc(uid); // usersに変更 (元コードに合わせて修正)

    try {
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userProfileRef);
        if (!userDoc.exists) return;

        const profileData = userDoc.data();
        if (!profileData) return;

        const currentStreak = profileData.currentStreak || 0;
        const lastPostTimestamp = profileData.lastPostDate;
        const todayJST = getJSTDate(postCreatedAt);

        if (!lastPostTimestamp) {
          transaction.update(userProfileRef, {
            currentStreak: 1,
            lastPostDate: postCreatedAt,
          });
          return;
        }

        const lastPostDate = lastPostTimestamp.toDate();
        const lastPostDayJST = getJSTDate(lastPostDate);

        if (lastPostDayJST === todayJST) {
          transaction.update(userProfileRef, { lastPostDate: postCreatedAt });
          return;
        }

        const yesterdayDate = new Date(
          postCreatedAt.getTime() - 24 * 60 * 60 * 1000
        );
        const yesterdayJST = getJSTDate(yesterdayDate);

        if (lastPostDayJST === yesterdayJST) {
          transaction.update(userProfileRef, {
            currentStreak: currentStreak + 1,
            lastPostDate: postCreatedAt,
          });
        } else {
          transaction.update(userProfileRef, {
            currentStreak: 1,
            lastPostDate: postCreatedAt,
          });
        }
      });
    } catch (error) {
      logger.error("Streak update failed:", error);
    }

    // ついでに通知処理も呼び出す（構成をシンプルにするためここに統合しても良いですが、今回は独立させておきます）
  }
);

// ---------------------------------------------------------
// 2. プッシュ通知送信 (既存)
// ---------------------------------------------------------
export const sendPushNotification = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    region: "asia-northeast1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const notification = snapshot.data();
    const targetUserId = notification.targetUserId;

    if (notification.fromUserId === targetUserId) return;

    try {
      const userDoc = await db.collection("users").doc(targetUserId).get();
      const fcmToken = userDoc.data()?.fcmToken;
      if (!fcmToken) return;

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
        case "friend_request":
          title = "フレンド申請";
          body = `${senderName}さんからフレンド申請が届きました`;
          break;
        case "quest_invite":
          title = "✉️ クエスト招待";
          body = `${senderName}さんが「${notification.questTitle}」にあなたを招待しました！`;
          break;
        case "quest_update":
          title = "仲間が記録しました！";
          body = notification.message || "フレンドクエストの進捗があります";
          break;
        case "battle_result": // 追加
          title = "🏆 バトル結果発表！";
          body = `「${notification.questTitle}」の結果が出ました。タップして確認しよう！`;
          break;
      }

      const message = {
        token: fcmToken,
        notification: { title, body },
        data: {
          type: notification.type,
          postId: notification.postId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
      };

      await admin.messaging().send(message);
    } catch (error) {
      logger.error("Error sending notification:", error);
    }
  }
);

// ---------------------------------------------------------
// 3. 投稿時に参加者へ通知 (既存)
// ---------------------------------------------------------
export const notifyQuestParticipants = onDocumentCreated(
  {
    document: "posts/{postId}",
    region: "asia-northeast1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const post = snapshot.data();
    const myQuestId = post.myQuestId;

    if (!myQuestId) return;

    try {
      const questDoc = await db.collection("my_quests").doc(myQuestId).get();
      if (!questDoc.exists) return;

      const quest = questDoc.data();
      if (!quest || quest.type === "personal") return;

      const participants: string[] = quest.participantIds || [];
      const senderUid = post.uid;
      const senderName = post.userName;

      const targets = participants.filter((uid) => uid !== senderUid);
      if (targets.length === 0) return;

      const batch = db.batch();
      for (const targetUid of targets) {
        const notifRef = db.collection("notifications").doc();
        batch.set(notifRef, {
          type: "quest_update",
          fromUserId: senderUid,
          fromUserName: senderName,
          targetUserId: targetUid,
          postId: event.params.postId,
          questTitle: quest.title,
          message: `${senderName}さんが「${quest.title}」の進捗を記録しました！`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
        });
      }
      await batch.commit();
    } catch (error) {
      logger.error("Error notifying participants:", error);
    }
  }
);

// ---------------------------------------------------------
// 4. 【新規】毎日0時に終了したバトルを集計して結果発表
// ---------------------------------------------------------
export const checkFinishedBattlesAndPostResults = onSchedule(
  {
    schedule: "0 0 * * *", // 毎日 日本時間 0:00 (JST)
    timeZone: "Asia/Tokyo",
    region: "asia-northeast1",
  },
  async (event) => {
    const now = new Date();
    // 「昨日」の日付を取得（0時に実行されるので、前日に終了したクエストを探す）
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const yesterdayStr = getJSTDate(yesterday); // "YYYY-MM-DD"

    logger.log(`Checking battles finished on: ${yesterdayStr}`);

    try {
      // 昨日終了したバトルクエストを取得
      const questsSnapshot = await db
        .collection("my_quests")
        .where("endDate", "==", yesterdayStr)
        .where("type", "==", "battle")
        .where("status", "==", "active") // まだ完了処理されていないもの
        .get();

      if (questsSnapshot.empty) {
        logger.log("No finished battles found.");
        return;
      }

      const batch = db.batch();

      for (const questDoc of questsSnapshot.docs) {
        const quest = questDoc.data();
        const questId = questDoc.id;
        const participants: string[] = quest.participantIds || [];

        // このクエストの全投稿を取得して集計
        const postsSnapshot = await db
          .collection("posts")
          .where("myQuestId", "==", questId)
          .get();

        // 集計用マップ
        const stats: Record<
          string,
          {
            name: string;
            effort: number;
            posts: number;
            cheers: number;
            score: number;
          }
        > = {};

        // 初期化
        // (ユーザー名は投稿データから拾うか、別途取得が必要だが簡易的に投稿から拾う)
        for (const uid of participants) {
          stats[uid] = {
            name: "Unknown",
            effort: 0,
            posts: 0,
            cheers: 0,
            score: 0,
          };
        }

        // 集計
        postsSnapshot.forEach((doc) => {
          const p = doc.data();
          const uid = p.uid;
          if (stats[uid]) {
            stats[uid].name = p.userName || stats[uid].name;
            stats[uid].effort += p.timeSpentHours || 0;
            stats[uid].posts += 1;
            stats[uid].cheers += p.likeCount || 0;
          }
        });

        // スコア計算 (時間*10 + 回数*5 + 応援*2)
        const results = Object.values(stats).map((s) => {
          s.score = s.effort * 10 + s.posts * 5 + s.cheers * 2;
          return s;
        });

        // ソート (降順)
        results.sort((a, b) => b.score - a.score);

        // 結果発表の投稿テキスト作成
        let resultText = `🏆 フレンドバトル結果発表！\n\nクエスト: ${quest.title}\n\n`;

        results.forEach((r, index) => {
          let rankIcon = "";
          if (index === 0) rankIcon = "🥇";
          else if (index === 1) rankIcon = "🥈";
          else if (index === 2) rankIcon = "🥉";
          else rankIcon = `${index + 1}位`;

          resultText += `${rankIcon} ${r.name} (${Math.floor(r.score)}pt)\n`;
          resultText += `   ⏱️ ${r.effort.toFixed(1)}h  📝 ${r.posts}回  🔥 ${
            r.cheers
          }\n\n`;
        });

        resultText += "参加者の皆さん、お疲れ様でした！👏";

        // 結果を投稿 (クエスト作成者の名義で)
        const resultPostRef = db.collection("posts").doc();
        batch.set(resultPostRef, {
          uid: quest.uid, // 作成者
          userName: quest.userName || "MiniQuest System",
          userAvatar: quest.userPhotoURL || null,
          userLevel: 0, // システム投稿なので0または適当な値
          userClass: "運営",
          text: resultText,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          likeCount: 0,
          commentCount: 0,
          myQuestId: questId,
          myQuestTitle: quest.title,
          questCategory: quest.category,
          isBlessed: false,
          isWisdomShared: false,
          isShortPost: false,
          isResultPost: true, // 結果発表用のフラグ（必要ならFlutter側でデザインを変える用）
        });

        // クエストを完了状態にする
        const questRef = db.collection("my_quests").doc(questId);
        batch.update(questRef, { status: "completed" });

        // 参加者全員に通知
        for (const uid of participants) {
          const notifRef = db.collection("notifications").doc();
          batch.set(notifRef, {
            type: "battle_result",
            fromUserId: quest.uid,
            targetUserId: uid,
            questTitle: quest.title,
            postId: resultPostRef.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
          });
        }
      }

      await batch.commit();
      logger.log("Battle results posted successfully.");
    } catch (error) {
      logger.error("Error posting battle results:", error);
    }
  }
);
