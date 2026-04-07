//
//  HomeSetupState.swift
//  Flamora app
//
//  Setup state machine for Home (S0–S5).
//  Decoded from `get-setup-state` Edge Function.
//

import Foundation

// MARK: - Setup Stage

/// S0–S5 setup stages that drive Home rendering.
/// Decoded from Edge Function response; stored in memory only (not @AppStorage).
enum HomeSetupStage: String, Codable, Equatable {
    case noGoal           = "no_goal"
    case goalSet          = "goal_set"
    case accountsLinked   = "accounts_linked"
    case snapshotPending  = "snapshot_pending"
    case planPending      = "plan_pending"
    case active           = "active"

    /// Whether the user has completed the full setup flow.
    var isFullySetup: Bool { self == .active }

    /// Whether a guided setup card should be shown.
    var needsGuidedCard: Bool { self != .active }
}

// MARK: - Setup State Response

/// Full response from `get-setup-state`.
struct HomeSetupStateResponse: Codable {
    let setupStage: HomeSetupStage
    let lastIncompleteStage: HomeSetupStage?

    let goalCompletedAt: String?
    let accountsReviewedAt: String?
    let snapshotReviewedAt: String?
    let planAppliedAt: String?

    let activePlanId: String?
    let activeGoalId: String?

    enum CodingKeys: String, CodingKey {
        case setupStage           = "setup_stage"
        case lastIncompleteStage  = "last_incomplete_stage"
        case goalCompletedAt      = "goal_completed_at"
        case accountsReviewedAt   = "accounts_reviewed_at"
        case snapshotReviewedAt   = "snapshot_reviewed_at"
        case planAppliedAt        = "plan_applied_at"
        case activePlanId         = "active_plan_id"
        case activeGoalId         = "active_goal_id"
    }

    /// Convenience: the stage to resume the setup flow from.
    var resumeStage: HomeSetupStage {
        lastIncompleteStage ?? setupStage
    }
}

// MARK: - Guided Setup Card Content

/// Copy + CTA for the guided setup card shown in S0–S4.
struct GuidedSetupCardContent {
    let title: String
    let body: String
    let ctaLabel: String

    static func content(for stage: HomeSetupStage) -> GuidedSetupCardContent {
        switch stage {
        case .noGoal:
            return GuidedSetupCardContent(
                title: "Set your FIRE goal",
                body: "Tell us what retirement should cost so we can estimate your real path.",
                ctaLabel: "Set my goal"
            )
        case .goalSet:
            return GuidedSetupCardContent(
                title: "Connect your accounts",
                body: "Link checking, savings, credit, and investment accounts to reveal your real starting point.",
                ctaLabel: "Connect accounts"
            )
        case .accountsLinked:
            return GuidedSetupCardContent(
                title: "Review connected accounts",
                body: "Confirm your linked accounts before we build your financial snapshot.",
                ctaLabel: "Review accounts"
            )
        case .snapshotPending:
            return GuidedSetupCardContent(
                title: "See where you stand",
                body: "We analyzed your finances. Review your snapshot before choosing a plan.",
                ctaLabel: "See my snapshot"
            )
        case .planPending:
            return GuidedSetupCardContent(
                title: "Choose your path",
                body: "Pick the plan that fits your FIRE goal and current finances.",
                ctaLabel: "Choose a plan"
            )
        case .active:
            // No guided card in active state
            return GuidedSetupCardContent(title: "", body: "", ctaLabel: "")
        }
    }
}
