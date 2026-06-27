const stripe = require('stripe')('sk_test_51Rg5GuDE9BzKscrP29ObWtDSE8qghsItfyoSF21xVUXUpfzgolCqR6QEokwaWRS0WT2qIdsrc3Yq8RVXdhT3oeTx00pffwoetj');

async function run() {
  try {
    const customer = await stripe.customers.create({
      email: "test@example.com",
    });

    const subscription = await stripe.subscriptions.create({
      customer: customer.id,
      items: [{ price: 'price_1TiKYZDE9BzKscrPPk3Tjbgh' }],
      payment_behavior: 'default_incomplete',
      payment_settings: { save_default_payment_method: 'on_subscription' },
      expand: ['latest_invoice.payment_intent', 'pending_setup_intent'],
    });

    console.log("payment_intent type:", typeof subscription.latest_invoice.payment_intent);
    console.log("payment_intent:", subscription.latest_invoice.payment_intent);
    console.log("pending_setup_intent:", subscription.pending_setup_intent);
  } catch (e) {
    console.error(e);
  }
}

run();
