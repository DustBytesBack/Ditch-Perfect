const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {getFirestore} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");

initializeApp();

exports.computeRanking = onDocumentCreated(
    "rankings/{docId}",
    async (event) => {
      const data = event.data.data();
      if (!data) return;

      const subjects = data.subjects || [];
      let totalAttended = 0;
      let totalClasses = 0;

      subjects.forEach((subject) => {
        totalAttended += (subject.attendedClasses || 0);
        totalClasses += (subject.totalClasses || 0);
      });

      if (totalClasses === 0) return;

      const attendancePercentage = (totalAttended / totalClasses) * 100;

      // Users whose attendance is closest to 75% rank higher.
      const distanceFromTarget = Math.abs(attendancePercentage - 75);
      const rankingScore = 100 - distanceFromTarget;

      const db = getFirestore();

      // We use the username as ID so each user only has one entry
      const username = data.username || "Anonymous";

      await db.collection("leaderboard").doc(username).set({
        username: username,
        attendancePercent: attendancePercentage,
        rankingScore: rankingScore,
        updatedAt: event.data.updateTime || new Date(),
      });

      console.log(`Updated leaderboard for ${username}: ` +
            `Score ${rankingScore.toFixed(2)}`);
    },
);
