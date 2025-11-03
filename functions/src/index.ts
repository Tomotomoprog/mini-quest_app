import { onDocumentCreated } from "firebase-functions/v2/firestore"; // ◀◀◀ v2のimportに変更
import * as logger from "firebase-functions/logger"; // ◀◀◀ v2のロガーに変更
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

// ▼▼▼ [修正] v2 (onDocumentCreated) の構文に変更 ▼▼▼
export const updateStreakOnPostCreate = onDocumentCreated(
  {
    document: "posts/{postId}", // ◀◀◀ 監視対象のドキュメント
    region: "asia-northeast1", // ◀◀◀ リージョン指定
  },
  async (event) => { // ◀◀◀ event パラメータ
    
    // ◀◀◀ event から snapshot を取得
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
    const postCreatedAt = post.createdAt.toDate(); // 投稿の作成日時(Timestamp -> Date)

    // [重要] 'user_profiles' を参照するようにしています
    const userProfileRef = db.collection("user_profiles").doc(uid);

    try {
      // トランザクションで安全にプロフィールを更新
      await db.runTransaction(async (transaction) => {
        const userProfileDoc = await transaction.get(userProfileRef);
        if (!userProfileDoc.exists) {
          logger.log(`ユーザー(uid: ${uid})のプロフィールが見つかりません`);
          return;
        }

        const profileData = userProfileDoc.data();
        if (!profileData) return;

        // 現在の連続記録と最後の投稿日を取得
        const currentStreak: number = profileData.currentStreak ?? 0;
        const lastPostTimestamp: admin.firestore.Timestamp | undefined =
          profileData.lastPostDate;

        // JST（日本時間）で日付を比較
        const todayJST = getJSTDate(postCreatedAt);

        if (!lastPostTimestamp) {
          // 1. 初めての投稿
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
          // 2. 今日すでに投稿している（日付が変わっていない）
          logger.log("本日2回目以降の投稿。ストリークは変更なし。");
          // 最後の投稿日時だけ最新のものに更新
          transaction.update(userProfileRef, {
            lastPostDate: postCreatedAt,
          });
          return;
        }

        // 昨日の日付をJSTで計算
        const yesterdayDate = new Date(postCreatedAt.getTime() - 24 * 60 * 60 * 1000);
        const yesterdayJST = getJSTDate(yesterdayDate);

        if (lastPostDayJST === yesterdayJST) {
          // 3. 昨日から連続している
          logger.log("連続投稿成功。ストリークをインクリメント。");
          transaction.update(userProfileRef, {
            currentStreak: currentStreak + 1, // トランザクション内で読み取った値に+1する
            lastPostDate: postCreatedAt,
          });
        } else {
          // 4. 連続が途切れている（一昨日以前）
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
// ▲▲▲