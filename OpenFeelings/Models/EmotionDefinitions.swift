import Foundation

struct EmotionDefinition: Hashable {
    let title: String
    let summary: String
}

struct EmotionReferenceSource: Identifiable, Hashable {
    let title: String
    let url: URL

    var id: URL { url }
}

enum EmotionDefinitions {
    static let sourceSummary = "Original educational summaries informed by the APA Dictionary of Psychology, NIH Toolbox Emotion Domain guidance, NIMH anxiety and fear resources, NIH Clinical Center grief material, and the Open Emotion Wheel taxonomy."

    static let disclaimer = "These descriptions are for reflection and education, not diagnosis or treatment advice."

    static let referenceSources = [
        EmotionReferenceSource(
            title: "APA Dictionary of Psychology",
            url: URL(string: "https://www.apa.org/pubs/books/4311007.html")!
        ),
        EmotionReferenceSource(
            title: "NIH Toolbox Emotion Domain",
            url: URL(string: "https://resources.nihtoolbox.org/wp-content/uploads/2022/05/Toolbox_Scoring_and_Interpretation_Guide_for_iPad_v1.7-5.25.21.pdf")!
        ),
        EmotionReferenceSource(
            title: "NIMH Anxiety Disorders",
            url: URL(string: "https://www.nimh.nih.gov/health/topics/anxiety-disorders")!
        ),
        EmotionReferenceSource(
            title: "NIMH Acute Threat/Fear",
            url: URL(string: "https://www.nimh.nih.gov/research/research-funded-by-nimh/rdoc/constructs/acute-threat-fear")!
        ),
        EmotionReferenceSource(
            title: "NIH Clinical Center Grief",
            url: URL(string: "https://www.cc.nih.gov/bereavement")!
        )
    ]

    static let referenceURLs = referenceSources.map(\.url)

    static func definition(for id: String) -> EmotionDefinition {
        definitions[id] ?? EmotionDefinition(
            title: "Emotion",
            summary: "A feeling state that can carry information about needs, safety, connection, loss, or values."
        )
    }

    static func hasDefinition(for id: String) -> Bool {
        definitions[id] != nil
    }

    private static let definitions: [String: EmotionDefinition] = [
        "happy": EmotionDefinition(
            title: "Happy",
            summary: "A pleasant emotional state marked by positive affect, satisfaction, or a sense that things are going well."
        ),
        "sad": EmotionDefinition(
            title: "Sad",
            summary: "An unpleasant state involving loss, disappointment, low mood, or reduced energy for engaging with life."
        ),
        "angry": EmotionDefinition(
            title: "Angry",
            summary: "A high-arousal negative emotion that arises when a person perceives threat, unfairness, obstruction, or boundary violation."
        ),
        "fearful": EmotionDefinition(
            title: "Fearful",
            summary: "A threat-focused state involving alertness, tension, and readiness to protect yourself from possible harm."
        ),
        "disgusted": EmotionDefinition(
            title: "Disgusted",
            summary: "An aversive response to something experienced as contaminating, offensive, morally troubling, or strongly unwanted."
        ),

        "optimistic": EmotionDefinition(
            title: "Optimistic",
            summary: "A future-oriented expectation that things can improve or turn out well."
        ),
        "hopeful": EmotionDefinition(
            title: "Hopeful",
            summary: "A positive expectancy that a desired outcome is possible, often paired with motivation to move toward it."
        ),
        "inspired": EmotionDefinition(
            title: "Inspired",
            summary: "A lifted, energized state in which something feels meaningful enough to prompt action or creativity."
        ),
        "peaceful": EmotionDefinition(
            title: "Peaceful",
            summary: "A calm state with low internal conflict, reduced tension, and a sense of safety or acceptance."
        ),
        "loved": EmotionDefinition(
            title: "Loved",
            summary: "A felt sense of being valued, cared for, and emotionally connected to another person or group."
        ),
        "thankful": EmotionDefinition(
            title: "Thankful",
            summary: "Recognition and appreciation of benefit, care, support, or goodness received."
        ),
        "proud": EmotionDefinition(
            title: "Proud",
            summary: "A positive self-evaluative emotion linked to achievement, effort, integrity, or valued identity."
        ),
        "successful": EmotionDefinition(
            title: "Successful",
            summary: "A sense that an intended goal, role, or task has been achieved or is going well."
        ),
        "confident": EmotionDefinition(
            title: "Confident",
            summary: "A belief in your ability to handle a situation, make choices, or meet a challenge."
        ),
        "excited": EmotionDefinition(
            title: "Excited",
            summary: "A high-energy positive state involving anticipation, interest, and readiness for action."
        ),
        "eager": EmotionDefinition(
            title: "Eager",
            summary: "An active readiness or desire to begin, approach, or participate in something anticipated."
        ),
        "energetic": EmotionDefinition(
            title: "Energetic",
            summary: "A state of physical or mental activation that supports movement, engagement, or effort."
        ),
        "powerful": EmotionDefinition(
            title: "Powerful",
            summary: "A sense of agency, influence, or capacity to affect what happens."
        ),
        "courageous": EmotionDefinition(
            title: "Courageous",
            summary: "Willingness to act in line with values or needs despite fear, uncertainty, or risk."
        ),
        "creative": EmotionDefinition(
            title: "Creative",
            summary: "A flexible, generative state marked by openness to ideas, expression, or novel solutions."
        ),

        "lonely": EmotionDefinition(
            title: "Lonely",
            summary: "Distress from feeling insufficiently connected, seen, or emotionally close to others."
        ),
        "isolated": EmotionDefinition(
            title: "Isolated",
            summary: "A sense of being separated from support, belonging, or meaningful social contact."
        ),
        "abandoned": EmotionDefinition(
            title: "Abandoned",
            summary: "Painful perception of being left, rejected, or unsupported by someone important."
        ),
        "vulnerable": EmotionDefinition(
            title: "Vulnerable",
            summary: "A state of emotional openness or exposure in which harm, rejection, or overwhelm feels possible."
        ),
        "victimised": EmotionDefinition(
            title: "Victimised",
            summary: "A perception of being harmed, mistreated, or targeted by another person or system."
        ),
        "fragile": EmotionDefinition(
            title: "Fragile",
            summary: "A sense of being easily hurt, depleted, or unable to tolerate much additional stress."
        ),
        "despair": EmotionDefinition(
            title: "Despair",
            summary: "A deep loss of hope accompanied by helplessness, sadness, or a sense that options are gone."
        ),
        "grief": EmotionDefinition(
            title: "Grief",
            summary: "The emotional response to loss, often involving sadness, yearning, disruption, and adjustment over time."
        ),
        "powerless": EmotionDefinition(
            title: "Powerless",
            summary: "A sense of lacking control, influence, or ability to change what is happening."
        ),
        "guilty": EmotionDefinition(
            title: "Guilty",
            summary: "A self-conscious emotion that arises when you believe you have violated a value, rule, or responsibility."
        ),
        "remorseful": EmotionDefinition(
            title: "Remorseful",
            summary: "Regret and concern about harm done, often paired with a wish to repair or act differently."
        ),
        "ashamed": EmotionDefinition(
            title: "Ashamed",
            summary: "A painful self-focused feeling of being flawed, exposed, or unacceptable."
        ),
        "hurt": EmotionDefinition(
            title: "Hurt",
            summary: "Emotional pain after perceived rejection, loss, betrayal, criticism, or unmet care."
        ),
        "wounded": EmotionDefinition(
            title: "Wounded",
            summary: "A lingering sense of emotional injury after something felt deeply painful or violating."
        ),
        "disappointed": EmotionDefinition(
            title: "Disappointed",
            summary: "Sadness or frustration when reality falls short of expectations, hopes, or needs."
        ),

        "humiliated": EmotionDefinition(
            title: "Humiliated",
            summary: "Pain and anger from feeling degraded, exposed, or lowered in status before yourself or others."
        ),
        "disrespected": EmotionDefinition(
            title: "Disrespected",
            summary: "A feeling that your dignity, boundaries, or worth have been dismissed or treated as unimportant."
        ),
        "ridiculed": EmotionDefinition(
            title: "Ridiculed",
            summary: "Distress from feeling mocked, belittled, or made the object of contempt."
        ),
        "bitter": EmotionDefinition(
            title: "Bitter",
            summary: "Persistent resentment or hurt that remains after perceived unfairness, betrayal, or loss."
        ),
        "indignant": EmotionDefinition(
            title: "Indignant",
            summary: "Anger fueled by a sense that something is unjust, insulting, or morally wrong."
        ),
        "violated": EmotionDefinition(
            title: "Violated",
            summary: "A strong reaction to a boundary, trust, right, or personal safety being breached."
        ),
        "frustrated": EmotionDefinition(
            title: "Frustrated",
            summary: "Agitated distress when goals, needs, or action are blocked."
        ),
        "infuriated": EmotionDefinition(
            title: "Infuriated",
            summary: "Intense anger with high physiological arousal and a strong urge to confront or stop something."
        ),
        "annoyed": EmotionDefinition(
            title: "Annoyed",
            summary: "Mild to moderate irritation in response to repeated, unwanted, or obstructive experiences."
        ),
        "critical": EmotionDefinition(
            title: "Critical",
            summary: "A judging or evaluative stance focused on flaws, risks, or what seems wrong."
        ),
        "sceptical": EmotionDefinition(
            title: "Sceptical",
            summary: "A cautious state of doubt that withholds trust or belief until there is more evidence."
        ),
        "dismissive": EmotionDefinition(
            title: "Dismissive",
            summary: "A distancing stance that minimizes, rejects, or devalues something or someone."
        ),
        "distant": EmotionDefinition(
            title: "Distant",
            summary: "Emotional withdrawal or reduced openness used to create space, safety, or control."
        ),
        "withdrawn": EmotionDefinition(
            title: "Withdrawn",
            summary: "Pulling back from contact, expression, or participation, often to conserve energy or avoid hurt."
        ),
        "numb": EmotionDefinition(
            title: "Numb",
            summary: "Reduced emotional responsiveness or sensation, often associated with overload, shock, or disconnection."
        ),

        "anxious": EmotionDefinition(
            title: "Anxious",
            summary: "Apprehension about possible future threat, uncertainty, or negative outcomes."
        ),
        "overwhelmed": EmotionDefinition(
            title: "Overwhelmed",
            summary: "A state in which demands feel greater than your available capacity to cope."
        ),
        "worried": EmotionDefinition(
            title: "Worried",
            summary: "Repetitive concern about what might happen, often focused on risk, uncertainty, or responsibility."
        ),
        "insecure": EmotionDefinition(
            title: "Insecure",
            summary: "Uncertainty about safety, acceptance, ability, or worth in a situation or relationship."
        ),
        "inadequate": EmotionDefinition(
            title: "Inadequate",
            summary: "A belief or feeling that you are not enough for the task, role, or expectation at hand."
        ),
        "inferior": EmotionDefinition(
            title: "Inferior",
            summary: "A painful comparison-based sense of being less capable, worthy, or valued than others."
        ),
        "weak": EmotionDefinition(
            title: "Weak",
            summary: "A feeling of reduced strength, agency, or capacity to cope with demands."
        ),
        "worthless": EmotionDefinition(
            title: "Worthless",
            summary: "A painful feeling of having little value, importance, or deservingness."
        ),
        "insignificant": EmotionDefinition(
            title: "Insignificant",
            summary: "A sense of being unseen, unimportant, or without meaningful impact."
        ),
        "rejected": EmotionDefinition(
            title: "Rejected",
            summary: "Pain from perceived exclusion, refusal, or loss of acceptance."
        ),
        "excluded": EmotionDefinition(
            title: "Excluded",
            summary: "A sense of being left out of connection, belonging, decision-making, or shared experience."
        ),
        "persecuted": EmotionDefinition(
            title: "Persecuted",
            summary: "A perception of being unfairly targeted, harassed, or treated as an enemy."
        ),
        "threatened": EmotionDefinition(
            title: "Threatened",
            summary: "A state of perceived danger to safety, status, relationship, values, or resources."
        ),
        "nervous": EmotionDefinition(
            title: "Nervous",
            summary: "Tense anticipation with bodily arousal, often before uncertainty, evaluation, or possible threat."
        ),
        "exposed": EmotionDefinition(
            title: "Exposed",
            summary: "A feeling of being visible, unprotected, or at risk of judgment or harm."
        ),

        "repelled": EmotionDefinition(
            title: "Repelled",
            summary: "A strong urge to move away from something experienced as offensive, unsafe, or unacceptable."
        ),
        "horrified": EmotionDefinition(
            title: "Horrified",
            summary: "Shock and fear in response to something perceived as deeply disturbing, harmful, or morally alarming."
        ),
        "hesitant": EmotionDefinition(
            title: "Hesitant",
            summary: "A cautious pause when uncertainty, risk, or mixed feelings make action feel difficult."
        ),
        "awful": EmotionDefinition(
            title: "Awful",
            summary: "A global negative appraisal that something feels very bad, distressing, or hard to tolerate."
        ),
        "nauseated": EmotionDefinition(
            title: "Nauseated",
            summary: "A bodily or emotional queasiness linked to aversion, revulsion, or stress."
        ),
        "detestable": EmotionDefinition(
            title: "Detestable",
            summary: "Strong aversion toward something judged as unacceptable, harmful, or morally objectionable."
        ),
        "disenchanted": EmotionDefinition(
            title: "Disenchanted",
            summary: "Loss of trust, admiration, or positive expectation after disappointment or disillusionment."
        ),
        "appalled": EmotionDefinition(
            title: "Appalled",
            summary: "A shocked aversive reaction to something experienced as unacceptable or deeply wrong."
        ),
        "revolted": EmotionDefinition(
            title: "Revolted",
            summary: "Intense disgust with a strong impulse to reject, avoid, or separate from the trigger."
        ),
        "disapproving": EmotionDefinition(
            title: "Disapproving",
            summary: "A negative moral or evaluative response to behavior, choices, or conditions judged as wrong."
        ),
        "judgemental": EmotionDefinition(
            title: "Judgemental",
            summary: "A stance of evaluating or labeling something as flawed, wrong, or unacceptable."
        ),
        "embarrassed": EmotionDefinition(
            title: "Embarrassed",
            summary: "Self-conscious discomfort from feeling exposed, awkward, or socially evaluated."
        ),
        "startled": EmotionDefinition(
            title: "Startled",
            summary: "A brief automatic reaction to sudden or unexpected stimulation."
        ),
        "shocked": EmotionDefinition(
            title: "Shocked",
            summary: "Acute surprise and disruption after unexpected, intense, or upsetting information or events."
        ),
        "dismayed": EmotionDefinition(
            title: "Dismayed",
            summary: "Distress and discouragement in response to an unexpected problem, loss, or troubling development."
        )
    ]
}

extension EmotionSelection {
    var definition: EmotionDefinition {
        EmotionDefinitions.definition(for: specific?.id ?? secondary?.id ?? core.id)
    }
}
