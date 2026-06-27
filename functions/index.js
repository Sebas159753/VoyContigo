const functions = require("firebase-functions");
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
            data: {
              type: "match",
              matchId: newTripId,
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
            if (beforeData.status === "ACCEPTED" && afterData.acceptedByUid) {
                const uidsToNotify = [afterData.creatorUid];
                if (afterData.acceptedByUid) uidsToNotify.push(afterData.acceptedByUid);
                for (const uid of uidsToNotify) {
                    const userDoc = await admin.firestore().collection("users").doc(uid).get();
                    const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
                    if (fcmToken) {
                        const message = {
                            token: fcmToken,
                            notification: {
                                title: "Viaje Cancelado ⚠️",
                                body: "Uno de tus viajes programados ha sido cancelado.",
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
            }
        } else if (afterData.status === "COMPLETED" && beforeData.status !== "COMPLETED") {
            const db = admin.firestore();
            const uidsToUpdate = [afterData.creatorUid];
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
            const passengerUids = afterData.passengerUids || [];
            for (const uid of passengerUids) {
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

const stripe = require("stripe")("sk_test_51Rg5GuDE9BzKscrP29ObWtDSE8qghsItfyoSF21xVUXUpfzgolCqR6QEokwaWRS0WT2qIdsrc3Yq8RVXdhT3oeTx00pffwoetj");

exports.createSubscription = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  try {
    const { uid, email } = req.body;
    if (!uid || !email) {
      res.status(400).send({ error: "Falta uid o email" });
      return;
    }

    const customer = await stripe.customers.create({
      email: email,
      metadata: { uid: uid },
    });

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customer.id },
      { apiVersion: "2023-10-16" } 
    );

    // Create a PaymentIntent instead of a Subscription to force client_secret generation
    const paymentIntent = await stripe.paymentIntents.create({
      amount: 999,
      currency: 'usd',
      customer: customer.id,
      setup_future_usage: 'off_session',
      automatic_payment_methods: { enabled: true },
    });

    res.json({
      subscriptionId: paymentIntent.id,
      clientSecret: paymentIntent.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customer: customer.id,
    });
  } catch (error) {
    console.error("Error creating subscription:", error);
    res.status(500).send({ error: error.message });
  }
});

exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  const endpointSecret = "whsec_IlrESoiKlYEKn7G92cm6x7XyDKDkuvww";
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
  } catch (err) {
    console.error("Webhook Error:", err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  if (event.type === 'payment_intent.succeeded') {
    const paymentIntent = event.data.object;
    
    // Set default payment method and create real subscription
    if (paymentIntent.customer) {
      if (paymentIntent.payment_method) {
        await stripe.customers.update(paymentIntent.customer, {
          invoice_settings: { default_payment_method: paymentIntent.payment_method },
        });
      }

      const sub = await stripe.subscriptions.create({
        customer: paymentIntent.customer,
        items: [{ price: 'price_1TiKYZDE9BzKscrPPk3Tjbgh' }],
        trial_period_days: 30, // We already charged them for the first month via PaymentIntent
      });

      const customerObj = await stripe.customers.retrieve(paymentIntent.customer);
      const uid = customerObj.metadata.uid;
      if (uid) {
        const db = admin.firestore();
        await db.collection("users").doc(uid).update({
          isSubscribed: true,
          stripeSubscriptionId: sub.id, 
        });
      }
    }
  } else if (event.type === "invoice.payment_succeeded") {
    const invoice = event.data.object;
    if (invoice.subscription && invoice.amount_paid > 0) {
      const customer = await stripe.customers.retrieve(invoice.customer);
      const uid = customer.metadata.uid;
      if (uid) {
        await admin.firestore().collection("users").doc(uid).update({
          isSubscribed: true,
          stripeSubscriptionId: invoice.subscription,
        });
      }
    }
  } else if (event.type === "customer.subscription.deleted" || event.type === "invoice.payment_failed") {
    const obj = event.data.object;
    const customer = await stripe.customers.retrieve(obj.customer);
    const uid = customer.metadata.uid;
    if (uid) {
      await admin.firestore().collection("users").doc(uid).update({
        isSubscribed: false,
      });
    }
  }

  res.json({ received: true });
});

exports.cancelSubscription = functions.https.onRequest(async (req, res) => {
  const { uid } = req.body;
  if (!uid) {
    return res.status(400).send({ error: "Missing uid" });
  }

  try {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) {
      return res.status(404).send({ error: "User not found" });
    }

    const subId = userDoc.data().stripeSubscriptionId;
    if (subId && subId.startsWith('sub_')) {
      await stripe.subscriptions.cancel(subId);
    }

    await admin.firestore().collection("users").doc(uid).update({
      isSubscribed: false,
      stripeSubscriptionId: admin.firestore.FieldValue.delete(),
    });

    res.json({ success: true });
  } catch (error) {
    console.error("Error cancelling subscription:", error);
    res.status(500).send({ error: error.message });
  }
});
