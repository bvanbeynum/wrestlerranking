
use("fortmill");
db.wrestlers.countDocuments();

use("fortmill");
db.wrestlers.stats({ scale: 1024 * 1024 });

use("fortmill");
db.wrestlers.aggregate([
  {
    $group: {
      _id: null,
      averageValue: { $avg: "$price" },
      minValue: { $min: "$price" },
      maxValue: { $max: "$price" }
    }
  }
]);

use("fortmill");
db.wrestlers.find().limit(1)

use("fortmill");
// Run this one time to update all existing documents
db.wrestlers.updateMany(
  { name: { $exists: true } },
  [
    { $set: { searchName: { $toLower: "$name" } } }
  ]
);

use("fortmill");
db.wrestlers.createIndex({ searchName: 1 });

use("fortmill")
db.wrestlers.updateMany(
  { "events.team": { $exists: true } }, // Find documents that have this field
  [
    {
      $set: {
        events: {
          $map: {
            input: "$events",
            as: "event", // Variable for each object in the array
            in: {
              $mergeObjects: [ // Merges the original event object...
                "$$event",
                { // ...with our new normalized field
                  searchTeam: { 
                    $toLower: { $ifNull: [ "$$event.team", null ] } 
                  }
                }
              ]
            }
          }
        }
      }
    }
  ]
)

use("fortmill")
db.wrestlers.createIndex({ "events.searchTeam": 1 })
