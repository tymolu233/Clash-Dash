import SwiftUI

struct SubscriptionList: View {
    let subscriptions: [ConfigSubscription]
    let onEdit: (ConfigSubscription) -> Void
    let onToggle: (ConfigSubscription, Bool) -> Void
    let onUpdate: (ConfigSubscription) -> Void
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(subscriptions) { subscription in
                SubscriptionCard(
                    subscription: subscription,
                    onEdit: { onEdit(subscription) },
                    onToggle: { enabled in onToggle(subscription, enabled) }
//                    onUpdate: { onUpdate(subscription) }
                )
            }
        }
    }
} 
