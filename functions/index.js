// API v1 explícita: desde firebase-functions v5+ el import raíz expone la v2.
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const geofire = require("geofire-common");

admin.initializeApp();

exports.onTripCreated = functions.firestore
    .document("trips/{tripId}")
    .onCreate(async (snap, context) => {
      const newTrip = snap.data();
      const newTripId = context.params.tripId;

      if (newTrip.status !== "PENDING") return null;

      // 1. Calculate Geohashes if missing and coordinates are present
      let originGeohash = newTrip.originGeohash;
      let destGeohash = newTrip.destGeohash;

      if (!originGeohash && newTrip.originLat && newTrip.originLng && newTrip.destLat && newTrip.destLng) {
          originGeohash = geofire.geohashForLocation([newTrip.originLat, newTrip.originLng]);
          destGeohash = geofire.geohashForLocation([newTrip.destLat, newTrip.destLng]);
          await snap.ref.update({ originGeohash, destGeohash });
      }

      // Fallback for trips without coordinates (backwards compatibility)
      if (!originGeohash || !newTrip.originLat || !newTrip.destLat) {
          console.log(`Trip ${newTripId} missing coordinates, skipping scalable match.`);
          return null; 
      }

      const isOffer = newTrip.isOffer;
      const targetOrigin = [newTrip.originLat, newTrip.originLng];
      const targetDestination = [newTrip.destLat, newTrip.destLng];
      const scheduleTime = new Date(newTrip.scheduleTime);
      
      const timeWindowMs = 30 * 60 * 1000; // 30 minutes
      const minTime = new Date(scheduleTime.getTime() - timeWindowMs);
      const maxTime = new Date(scheduleTime.getTime() + timeWindowMs);

      const radiusInM = 5000; // 5 km radius for origin matching
      
      const bounds = geofire.geohashQueryBounds(targetOrigin, radiusInM);
      const promises = [];

      for (const b of bounds) {
          const q = admin.firestore().collection("trips")
            .where("isOffer", "==", !isOffer)
            .where("status", "==", "PENDING")
            .where("origin", "==", newTrip.origin)
            .where("destination", "==", newTrip.destination)
            .orderBy("originGeohash")
            .startAt(b[0])
            .endAt(b[1]);
          promises.push(q.get());
      }

      const snapshots = await Promise.all(promises);

      let matchedTrip = null;
      let matchedTripId = null;

      for (const querySnapshot of snapshots) {
          for (const doc of querySnapshot.docs) {
              const trip = doc.data();
              
              if (!trip.originLat || !trip.destLat) continue;

              const tripTime = new Date(trip.scheduleTime);
              
              if (tripTime >= minTime && tripTime <= maxTime) {
                  // Check distance for origin
                  const distanceOrigin = geofire.distanceBetween(targetOrigin, [trip.originLat, trip.originLng]) * 1000; // converted to meters
                  
                  if (distanceOrigin <= radiusInM) {
                      // Check distance for destination (also 5km radius)
                      const distanceDest = geofire.distanceBetween(targetDestination, [trip.destLat, trip.destLng]) * 1000;
                      
                      if (distanceDest <= radiusInM) {
                          matchedTrip = trip;
                          matchedTripId = doc.id;
                          break; 
                      }
                  }
              }
          }
          if (matchedTrip) break;
      }

      if (matchedTrip && matchedTripId) {
        console.log(`Scalable Match found! New Trip: ${newTripId}, Matched Trip: ${matchedTripId}`);
        
        // 1. Create match document
        await admin.firestore().collection("matches").add({
          offerTripId: isOffer ? newTripId : matchedTripId,
          demandTripId: isOffer ? matchedTripId : newTripId,
          offerUserId: isOffer ? newTrip.creatorUid : matchedTrip.creatorUid,
          demandUserId: isOffer ? matchedTrip.creatorUid : newTrip.creatorUid,
          status: "PENDING",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 2. Send Push Notification to the matched user
        const targetUserId = matchedTrip.creatorUid;
        const userDoc = await admin.firestore().collection("users").doc(targetUserId).get();
        const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

        if (fcmToken) {
          const message = {
            token: fcmToken,
            notification: {
              title: isOffer ? "🚗 ¡Nuevo conductor cerca!" : "👤 ¡Pasajero cerca de tu ruta!",
              body: isOffer 
                ? `Un conductor saldrá cerca de tu origen a una hora similar a la tuya.` 
                : `Alguien busca viajar cerca de tu ruta a una hora similar a tu oferta.`,
            },
            // El cliente enruta type=match a la pantalla de Coincidencias.
            data: {
              type: "match",
            },
            android: {
              priority: "high",
              notification: {
                channelId: "voycontigo_matches"
              }
            }
          };

          try {
            await admin.messaging().send(message);
            console.log("Notification sent successfully to", targetUserId);
          } catch (error) {
            console.error("Error sending notification:", error);
          }
        }
      }

      return null;
    });

exports.onTripUpdated = functions.firestore
    .document("trips/{tripId}")
    .onUpdate(async (change, context) => {
        const beforeData = change.before.data();
        const afterData = change.after.data();

        const beforePassengersLength = beforeData.passengers ? beforeData.passengers.length : 0;
        const afterPassengersLength = afterData.passengers ? afterData.passengers.length : 0;
        const etaJustTriggered = (!beforeData.etaTriggered && afterData.etaTriggered === true);

        if (beforeData.status === afterData.status && beforePassengersLength === afterPassengersLength && !etaJustTriggered) {
            return null;
        }

        const tripId = context.params.tripId;
        
        const beforePassengers = beforeData.passengers || [];
        const afterPassengers = afterData.passengers || [];
        
        if (afterPassengers.length > beforePassengers.length) {
            // Un pasajero se unió a la oferta
            const newPassenger = afterPassengers[afterPassengers.length - 1];
            const creatorUid = afterData.creatorUid;
            const userDoc = await admin.firestore().collection("users").doc(creatorUid).get();
            const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
            
            if (fcmToken) {
                const message = {
                    token: fcmToken,
                    notification: {
                        title: "¡Nuevo Pasajero! 🚗",
                        body: `${newPassenger.name || 'Alguien'} ha reservado un asiento en tu viaje.`,
                    },
                    data: { type: "passenger_joined", tripId: tripId },
                    android: {
                      priority: "high",
                      notification: {
                        channelId: "voycontigo_matches"
                      }
                    }
                };
                try {
                    await admin.messaging().send(message);
                    console.log("Passenger joined notification sent to", creatorUid);
                } catch (error) {
                    console.error("Error sending passenger joined notification:", error);
                }
            }
        } else if (afterPassengers.length < beforePassengers.length) {
            // Un pasajero canceló su reserva
            const creatorUid = afterData.creatorUid;
            const userDoc = await admin.firestore().collection("users").doc(creatorUid).get();
            const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
            
            if (fcmToken) {
                const message = {
                    token: fcmToken,
                    notification: {
                        title: "Pasajero Canceló ⚠️",
                        body: "Un pasajero ha cancelado su reserva. Se han liberado asientos en tu viaje.",
                    },
                    data: { type: "passenger_cancelled", tripId: tripId },
                    android: {
                      priority: "high",
                      notification: {
                        channelId: "voycontigo_matches"
                      }
                    }
                };
                try {
                    await admin.messaging().send(message);
                    console.log("Passenger cancelled notification sent to", creatorUid);
                } catch (error) {
                    console.error("Error sending notification:", error);
                }
            }
        }

        if (afterData.status === "ACCEPTED" && beforeData.status !== "ACCEPTED") {
            const creatorUid = afterData.creatorUid;
            const userDoc = await admin.firestore().collection("users").doc(creatorUid).get();
            const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
            
            if (fcmToken) {
                const message = {
                    token: fcmToken,
                    notification: {
                        title: afterData.isOffer ? "¡Pasajero Confirmado! 🎉" : "¡Viaje Confirmado! 🚗",
                        body: afterData.isOffer 
                            ? "Alguien ha reservado un asiento en tu viaje." 
                            : "Un conductor ha aceptado llevarte.",
                    },
                    data: { type: "trip_accepted", tripId: tripId },
                    android: {
                      priority: "high",
                      notification: {
                        channelId: "voycontigo_matches"
                      }
                    }
                };
                try {
                    await admin.messaging().send(message);
                    console.log("Accepted notification sent to", creatorUid);
                } catch (error) {
                    console.error("Error sending notification:", error);
                }
            }
        } else if (afterData.status === "EN_ROUTE" && beforeData.status !== "EN_ROUTE") {
            const uidsToNotify = [];
            if (afterData.isOffer && afterData.passengerUids) {
                uidsToNotify.push(...afterData.passengerUids);
            } else if (!afterData.isOffer && afterData.creatorUid) {
                // Si era una demanda, el pasajero es el creador
                uidsToNotify.push(afterData.creatorUid);
            }

            for (const uid of uidsToNotify) {
                const userDoc = await admin.firestore().collection("users").doc(uid).get();
                const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
                if (fcmToken) {
                    const message = {
                        token: fcmToken,
                        notification: {
                            title: "¡Conductor en camino! 🚗",
                            body: "Tu conductor ha iniciado el viaje. Prepárate en el punto de encuentro.",
                        },
                        data: { type: "trip_en_route", tripId: tripId },
                        android: {
                          priority: "high",
                          notification: {
                            channelId: "voycontigo_matches"
                          }
                        }
                    };
                    try {
                        await admin.messaging().send(message);
                    } catch (e) {
                        console.error("Error sending en_route notification:", e);
                    }
                }
            }
        } else if (afterData.status === "CANCELLED" && beforeData.status !== "CANCELLED") {
            const uidsToNotify = [];
            
            if (afterData.acceptedByUid) {
                uidsToNotify.push(afterData.acceptedByUid);
            }
            
            if (afterData.passengerUids && afterData.passengerUids.length > 0) {
                uidsToNotify.push(...afterData.passengerUids);
            }

            for (const uid of uidsToNotify) {
                const userDoc = await admin.firestore().collection("users").doc(uid).get();
                const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
                if (fcmToken) {
                    const message = {
                        token: fcmToken,
                        notification: {
                            title: "Viaje Cancelado ⚠️",
                            body: "El creador del viaje lo ha cancelado.",
                        },
                        data: { type: "trip_cancelled", tripId: tripId },
                        android: {
                          priority: "high",
                          notification: {
                            channelId: "voycontigo_matches"
                          }
                        }
                    };
                    try {
                        await admin.messaging().send(message);
                        console.log("Cancelled notification sent to", uid);
                    } catch (e) {
                        console.error("Error sending notification:", e);
                    }
                }
            }
        } else if (afterData.status === "COMPLETED" && beforeData.status !== "COMPLETED") {
            const db = admin.firestore();
            const uidsToUpdate = [afterData.creatorUid];
            // El conductor que aceptó una demanda también completa el viaje.
            if (afterData.acceptedByUid) {
                uidsToUpdate.push(afterData.acceptedByUid);
            }
            if (afterData.passengerUids && afterData.passengerUids.length > 0) {
                uidsToUpdate.push(...afterData.passengerUids);
            }
            
            const uniqueUids = [...new Set(uidsToUpdate)];
            
            const batch = db.batch();
            for (const uid of uniqueUids) {
                if (!uid) continue;
                const userRef = db.collection("users").doc(uid);
                batch.update(userRef, {
                    completedTrips: admin.firestore.FieldValue.increment(1)
                });
            }
            try {
                await batch.commit();
                console.log(`Incremented completedTrips for users: ${uniqueUids.join(', ')}`);
            } catch (e) {
                console.error("Error incrementing completed trips:", e);
            }
        }
        
        if (etaJustTriggered) {
            const etaUids = [...(afterData.passengerUids || [])];
            // En viajes tipo demanda el pasajero es el creador.
            if (!afterData.isOffer && afterData.creatorUid) {
                etaUids.push(afterData.creatorUid);
            }
            for (const uid of [...new Set(etaUids)]) {
                const userDoc = await admin.firestore().collection("users").doc(uid).get();
                const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
                
                if (fcmToken) {
                    const message = {
                        token: fcmToken,
                        notification: {
                            title: "¡Prepárate! ⏰",
                            body: "Tu conductor está a unos 5 minutos del punto de encuentro.",
                        },
                        data: { type: "eta_alert", tripId: tripId },
                        android: {
                          priority: "high",
                          notification: { channelId: "voycontigo_matches" }
                        }
                    };
                    try {
                        await admin.messaging().send(message);
                        console.log("ETA notification sent to passenger", uid);
                    } catch (error) {
                        console.error("Error sending ETA notification:", error);
                    }
                }
            }
        }

        return null;
    });

exports.onChatMessage = functions.firestore
    .document("trips/{tripId}/chat_messages/{messageId}")
    .onCreate(async (snap, context) => {
        const messageData = snap.data();
        const tripId = context.params.tripId;
        
        // Fetch trip to know who is involved
        const tripDoc = await admin.firestore().collection("trips").doc(tripId).get();
        if (!tripDoc.exists) return null;
        const trip = tripDoc.data();
        
        // Notify all participants except the sender
        const senderName = messageData.senderName || "Alguien";
        const senderUid = messageData.senderUid || null;
        const allParticipants = [trip.creatorUid];
        if (trip.acceptedByUid) allParticipants.push(trip.acceptedByUid);
        if (trip.passengers) {
            trip.passengers.forEach(p => allParticipants.push(p.uid));
        }
        
        const uniqueParticipants = [...new Set(allParticipants)];
        
        for (const uid of uniqueParticipants) {
            if (!uid) continue;
            const userDoc = await admin.firestore().collection("users").doc(uid).get();
            if (!userDoc.exists) continue;
            
            const userData = userDoc.data();
            // No notificar al propio remitente (identidad por UID).
            if (uid === senderUid) continue;

            const fcmToken = userData.fcmToken;
            if (fcmToken) {
                const payload = {
                    token: fcmToken,
                    notification: {
                        title: `Nuevo mensaje de ${senderName}`,
                        body: messageData.text || "Ha enviado un mensaje",
                    },
                    data: { type: "chat_message", tripId: tripId },
                    android: {
                      priority: "high",
                      notification: {
                        channelId: "voycontigo_matches"
                      }
                    }
                };
                
                try {
                    await admin.messaging().send(payload);
                } catch (e) {
                    console.error("Error sending chat notification:", e);
                }
            }
        }
        return null;
    });
