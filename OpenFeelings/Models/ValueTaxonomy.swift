import Foundation

/// One entry in the curated values deck used by the value-sort flow.
/// Adapted from established ACT card sorts (e.g. Bond/Hayes Personal
/// Values Card Sort) and shipped in code. The id is a stable slug that
/// MUST NEVER change once shipped — committed actions reference it.
struct ValueDefinition: Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let description: String
}

/// Namespace for the curated values deck shipped with the app.
enum ValueTaxonomy {
    static let all: [ValueDefinition] = [
        .init(id: "acceptance",    name: "Acceptance",    description: "Receiving myself and others as we are."),
        .init(id: "adventure",     name: "Adventure",     description: "Seeking out new and stimulating experiences."),
        .init(id: "authenticity",  name: "Authenticity",  description: "Acting in line with who I really am."),
        .init(id: "autonomy",      name: "Autonomy",      description: "Choosing my own path, free from coercion."),
        .init(id: "beauty",        name: "Beauty",        description: "Noticing and creating what is beautiful."),
        .init(id: "caring",        name: "Caring",        description: "Looking after others with warmth."),
        .init(id: "challenge",     name: "Challenge",     description: "Stretching myself with difficult goals."),
        .init(id: "community",     name: "Community",     description: "Belonging to and contributing to a group."),
        .init(id: "compassion",    name: "Compassion",    description: "Acting kindly toward suffering, mine and others'."),
        .init(id: "connection",    name: "Connection",    description: "Engaging fully with the people around me."),
        .init(id: "contribution",  name: "Contribution",  description: "Adding value to lives beyond my own."),
        .init(id: "cooperation",   name: "Cooperation",   description: "Working together toward shared aims."),
        .init(id: "courage",       name: "Courage",       description: "Acting on what matters even when afraid."),
        .init(id: "creativity",    name: "Creativity",    description: "Bringing something new into existence."),
        .init(id: "curiosity",     name: "Curiosity",     description: "Exploring, questioning, staying open."),
        .init(id: "dependability", name: "Dependability", description: "Being someone others can count on."),
        .init(id: "discipline",    name: "Discipline",    description: "Following through with steady effort."),
        .init(id: "equality",      name: "Equality",      description: "Treating people as having equal worth."),
        .init(id: "excitement",    name: "Excitement",    description: "Pursuing thrill and intensity."),
        .init(id: "fairness",      name: "Fairness",      description: "Acting with justice and impartiality."),
        .init(id: "faith",         name: "Faith",         description: "Holding a steady trust in something larger."),
        .init(id: "family",        name: "Family",        description: "Investing in the people I call family."),
        .init(id: "fitness",       name: "Fitness",       description: "Caring for my body's strength and health."),
        .init(id: "flexibility",   name: "Flexibility",   description: "Adapting gracefully to what shows up."),
        .init(id: "forgiveness",   name: "Forgiveness",   description: "Letting go of resentment, mine and others'."),
        .init(id: "freedom",       name: "Freedom",       description: "Living without unnecessary constraint."),
        .init(id: "friendship",    name: "Friendship",    description: "Building close, mutual friendships."),
        .init(id: "fun",           name: "Fun",           description: "Making space for play and lightness."),
        .init(id: "generosity",    name: "Generosity",    description: "Giving freely of what I have."),
        .init(id: "growth",        name: "Growth",        description: "Continuing to learn and change."),
        .init(id: "health",        name: "Health",        description: "Tending to my physical and mental wellbeing."),
        .init(id: "honesty",       name: "Honesty",       description: "Telling the truth, even when it costs."),
        .init(id: "humor",         name: "Humor",         description: "Finding and sharing the absurd."),
        .init(id: "independence",  name: "Independence",  description: "Standing on my own when it matters."),
        .init(id: "industry",      name: "Industry",      description: "Doing meaningful, useful work."),
        .init(id: "intimacy",      name: "Intimacy",      description: "Sharing closeness, body and mind."),
        .init(id: "justice",       name: "Justice",       description: "Working for what is right."),
        .init(id: "kindness",      name: "Kindness",      description: "Treating others gently and well."),
        .init(id: "knowledge",     name: "Knowledge",     description: "Seeking understanding for its own sake."),
        .init(id: "love",          name: "Love",          description: "Loving and being loved."),
        .init(id: "loyalty",       name: "Loyalty",       description: "Standing by the people and groups I commit to."),
        .init(id: "mindfulness",   name: "Mindfulness",   description: "Showing up in the present moment."),
        .init(id: "openness",      name: "Openness",      description: "Welcoming new ideas, people, experiences."),
        .init(id: "order",         name: "Order",         description: "Living with structure and clarity."),
        .init(id: "patience",      name: "Patience",      description: "Waiting and acting with steady calm."),
        .init(id: "peace",         name: "Peace",         description: "Cultivating inner and outer calm."),
        .init(id: "play",          name: "Play",          description: "Making time for what is purely enjoyable."),
        .init(id: "respect",       name: "Respect",       description: "Treating people and things with regard."),
        .init(id: "responsibility", name: "Responsibility", description: "Taking ownership of my actions and choices."),
        .init(id: "safety",        name: "Safety",        description: "Keeping myself and those I love secure."),
        .init(id: "self_care",     name: "Self-care",     description: "Looking after my own needs."),
        .init(id: "service",       name: "Service",       description: "Acting on behalf of others' wellbeing."),
        .init(id: "spirituality",  name: "Spirituality",  description: "Engaging with something beyond myself."),
        .init(id: "stability",     name: "Stability",     description: "Living with steady ground beneath me."),
        .init(id: "tradition",     name: "Tradition",     description: "Honoring practices passed down."),
        .init(id: "trust",         name: "Trust",         description: "Building and keeping trust with others.")
    ]

    static func definition(id: String) -> ValueDefinition? {
        all.first { $0.id == id }
    }
}
