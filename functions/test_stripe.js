const stripe = require('stripe')('sk_test_51Rg5GuDE9BzKscrP29ObWtDSE8qghsItfyoSF21xVUXUpfzgolCqR6QEokwaWRS0WT2qIdsrc3Yq8RVXdhT3oeTx00pffwoetj');

async function run() {
  try {
    const customer = await stripe.customers.create({
      email: "test3@example.com",
    });

    const pi = await stripe.paymentIntents.create({
      amount: 999,
      currency: 'usd',
      customer: customer.id,
      setup_future_usage: 'off_session',
      automatic_payment_methods: { enabled: true },
    });
    console.log("PI created:", pi.id, pi.client_secret);
  } catch (e) {
    console.error("Error creating PI:", e);
  }
}

run();
