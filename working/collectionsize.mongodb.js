
// use('fortmill');

// const collectionNames = db.getCollectionNames();

// collectionNames.forEach(function(collectionName) {
// 	const collectionStats = db.getCollection(collectionName).stats();
// 	if (collectionStats) {
// 		const storageSizeMB = (collectionStats.storageSize / (1024 * 1024)).toFixed(2);
// 		const collectionCount = collectionStats.count;
// 		print(`Collection: ${collectionName}, Count: ${collectionCount}, Size: ${storageSizeMB} MB`);
// 	}
// });


// use("fortmill");
// db.wrestlers.countDocuments();

// use("fortmill");
// db.wrestlers.stats({ scale: 1024 * 1024 });

use("fortmill");
db.wrestlers.find({ "event.searchTeam": "clover" }).limit(1)

// use("fortmill");
// // Run this one time to update all existing documents
// db.wrestlers.updateMany(
//   { name: { $exists: true } },
//   [
//     { $set: { searchName: { $toLower: "$name" } } }
//   ]
// );

// use("fortmill");
// db.wrestlers.createIndex({ searchName: 1 });
// db.wrestlers.createIndex({ searchNames: 1 });

// use("fortmill")
// db.wrestlers.updateMany(
//   { "events.team": { $exists: true } }, // Find documents that have this field
//   [
//     {
//       $set: {
//         events: {
//           $map: {
//             input: "$events",
//             as: "event", // Variable for each object in the array
//             in: {
//               $mergeObjects: [ // Merges the original event object...
//                 "$$event",
//                 { // ...with our new normalized field
//                   searchTeam: { 
//                     $toLower: { $ifNull: [ "$$event.team", null ] } 
//                   }
//                 }
//               ]
//             }
//           }
//         }
//       }
//     }
//   ]
// )

// use("fortmill")
// db.wrestlers.createIndex({ "events.searchTeam": 1 })
