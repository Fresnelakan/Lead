const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const {GoogleGenerativeAI} = require("@google/generative-ai");
const { onDocumentWritten } = require("firebase-functions/firestore");

const apiKey = functions.config().gemini.api_key;

if (!apiKey) {
    throw new Error("Gemini API key is not configured. Set it with: firebase functions:config:set gemini.api_key='YOUR_API_KEY'");
}
const genAI = new GoogleGenerativeAI(apiKey);

function convertTimeTo24Hour(timeString) {
    if (!timeString) return timeString;
    
    if (!timeString.includes('AM') && !timeString.includes('PM')) {
        return timeString;
    }
    
    const [time, period] = timeString.split(' ');
    let [hours, minutes] = time.split(':');
    hours = parseInt(hours);
    
    if (period === 'AM') {
        if (hours === 12) hours = 0;
    } else if (period === 'PM') {
        if (hours !== 12) hours += 12;
    }
    
    return `${hours.toString().padStart(2, '0')}:${minutes}`;
}

function normalizeTimetableData(data) {
    const normalized = {};
    
    for (const [day, activities] of Object.entries(data)) {
        if (Array.isArray(activities)) {
            normalized[day] = activities.map(activity => ({
                startTime: convertTimeTo24Hour(activity.startTime),
                endTime: convertTimeTo24Hour(activity.endTime),
                activity: activity.activity || '',
                type: activity.type || 'course',
                priority: activity.priority || 'medium',
                relatedSubject: activity.relatedSubject || null
            }));
        }
    }
    
    return normalized;
}

function analyzeScheduleGapsAndPatterns(timetableData) {
    const analysis = {
        freeTimeSlots: {},
        mealBreaks: {},
        subjectDistribution: {},
        cognitiveLoad: {},
        optimalIntervals: {},
        weeklyPattern: {}
    };
    
    const days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    
    for (const day of days) {
        const activities = timetableData[day] || [];
        
        analysis.freeTimeSlots[day] = findProductiveFreeSlots(activities);
        analysis.mealBreaks[day] = detectMealBreaks(activities);
        analysis.subjectDistribution[day] = analyzeSubjectDistribution(activities);
        analysis.cognitiveLoad[day] = calculateCognitiveLoad(activities);
    }
    
    analysis.weeklyPattern = analyzeWeeklyPatterns(timetableData);
    
    return analysis;
}

function findProductiveFreeSlots(activities) {
    const freeSlots = [];
    const timeSlots = generateTimeSlots(6, 23);
    
    const occupiedSlots = new Set();
    activities.forEach(activity => {
        const start = timeToMinutes(activity.startTime);
        const end = timeToMinutes(activity.endTime);
        
        for (let time = start; time < end; time += 15) {
            occupiedSlots.add(time);
        }
    });
    
    let currentFreeStart = null;
    let consecutiveFreeMinutes = 0;
    
    for (const timeSlot of timeSlots) {
        if (!occupiedSlots.has(timeSlot)) {
            if (currentFreeStart === null) {
                currentFreeStart = timeSlot;
                consecutiveFreeMinutes = 15;
            } else {
                consecutiveFreeMinutes += 15;
            }
        } else {
            if (consecutiveFreeMinutes >= 45) {
                freeSlots.push({
                    start: minutesToTime(currentFreeStart),
                    end: minutesToTime(currentFreeStart + consecutiveFreeMinutes),
                    duration: consecutiveFreeMinutes,
                    optimalFor: determineOptimalActivity(currentFreeStart, consecutiveFreeMinutes)
                });
            }
            currentFreeStart = null;
            consecutiveFreeMinutes = 0;
        }
    }
    
    if (consecutiveFreeMinutes >= 45) {
        freeSlots.push({
            start: minutesToTime(currentFreeStart),
            end: minutesToTime(currentFreeStart + consecutiveFreeMinutes),
            duration: consecutiveFreeMinutes,
            optimalFor: determineOptimalActivity(currentFreeStart, consecutiveFreeMinutes)
        });
    }
    
    return freeSlots;
}

function detectMealBreaks(activities) {
    const mealTimes = {
        breakfast: { start: 7*60, end: 9*60 },
        lunch: { start: 12*60, end: 14*60 },
        dinner: { start: 18*60, end: 20*60 }
    };
    
    const detectedMeals = {};
    
    for (const [mealType, timeRange] of Object.entries(mealTimes)) {
        const hasActivity = activities.some(activity => {
            const start = timeToMinutes(activity.startTime);
            const end = timeToMinutes(activity.endTime);
            return (start < timeRange.end && end > timeRange.start);
        });
        
        if (!hasActivity) {
            detectedMeals[mealType] = {
                suggested: true,
                start: minutesToTime(timeRange.start),
                end: minutesToTime(Math.min(timeRange.start + 60, timeRange.end)),
                duration: 60,
                priority: 'essential'
            };
        }
    }
    
    return detectedMeals;
}

function determineOptimalActivity(startTimeMinutes, durationMinutes) {
    const hour = Math.floor(startTimeMinutes / 60);
    
    if (hour >= 8 && hour <= 10) {
        if (durationMinutes >= 90) return 'deep_learning_math_physics';
        if (durationMinutes >= 60) return 'problem_solving_intensive';
        return 'quick_concept_review';
    }
    
    if (hour >= 10 && hour <= 12) {
        if (durationMinutes >= 120) return 'major_assignment_work';
        if (durationMinutes >= 90) return 'analytical_subjects';
        return 'concept_consolidation';
    }
    
    if (hour >= 14 && hour <= 16) {
        if (durationMinutes >= 90) return 'creative_subjects_languages';
        if (durationMinutes >= 60) return 'essay_writing_literature';
        return 'vocabulary_expansion';
    }
    
    if (hour >= 16 && hour <= 18) {
        if (durationMinutes >= 120) return 'memorization_intensive';
        if (durationMinutes >= 90) return 'history_geography_biology';
        return 'flashcard_review';
    }
    
    if (hour >= 18 && hour <= 20) {
        if (durationMinutes >= 90) return 'synthesis_organization';
        return 'daily_review_planning';
    }
    
    return 'light_review';
}

function generateSpacedRepetitionSystem(subjects, scheduleGaps) {
    const revisionIntervals = [1, 3, 7, 14, 30];
    const revisionPlan = {};
    
    subjects.forEach(subject => {
        revisionPlan[subject] = {
            immediate: [],
            shortTerm: [],
            mediumTerm: [],
            longTerm: [],
            examPrep: []
        };
    });
    
    return revisionPlan;
}

function generateWorldClassPrompt(timetableData, analysis) {
    return `Tu es un EXPERT EN NEUROSCIENCES DE L'APPRENTISSAGE de niveau Nobel Prize, spécialisé dans l'optimisation académique de niveau Corée du Sud/Singapour/Finlande.
Ton rôle est de transformer cet emploi du temps en SYSTÈME D'EXCELLENCE ACADÉMIQUE MONDIALE.

🎯 ANALYSE CONTEXTUELLE ULTRA-PROFONDE :
${JSON.stringify(analysis, null, 2)}

🧠 PRINCIPES NEUROSCIENTIFIQUES FONDAMENTAUX NIVEAU RECHERCHE :

1. COURBE D'OUBLI D'EBBINGHAUS (APPLICATION MILITAIRE) :
- Consolidation immédiate (0-30min post-cours) : +70% rétention
- Révision J+1 : +85% rétention avec 60-90min minimum
- Révision J+3 : +92% rétention avec techniques actives
- Révision J+7 : +96% rétention avec interconnexions
- Révision J+21 : +98% rétention permanente

2. RYTHMES CIRCADIENS OPTIMAUX (RECHERCHE MIT/STANFORD) :
- 6h-8h : Éveil cognitif, planification stratégique
- 8h-10h : ZONE DE GÉNIE - Mathématiques, Physique, Logique pure
- 10h-12h : Résolution problèmes complexes, Analyse critique
- 12h-13h : PAUSE DÉJEUNER OBLIGATOIRE (récupération neuronale)
- 13h-14h : Digestion cognitive, pas d'apprentissage intensif
- 14h-16h : Créativité maximale - Langues, Expression, Arts
- 16h-18h : Mémorisation active - Histoire, Géographie, Sciences naturelles
- 18h-20h : Synthèse, Organisation, Planification
- 20h-22h : Révision légère, Lecture, Préparation jour suivant

3. CHARGE COGNITIVE ET INTERFÉRENCE (THÉORIE DE SWELLER) :
- JAMAIS deux matières cognitives similaires consécutives
- Alternance OBLIGATOIRE : Abstrait → Concret → Créatif → Mémorisation
- Limite cognitive stricte : Maximum 3 sujets différents par session de 3h
- Temps de transition : 15min minimum entre changements cognitifs

4. PAUSES STRATÉGIQUES NIVEAU RECHERCHE :
- Technique Pomodoro AVANCÉE : 50min travail + 10min pause active
- Pause déjeuner : 60-90min OBLIGATOIRE (12h-14h optimal)
- Micro-pauses : 2min toutes les 25min pour oxygénation cérébrale
- Macro-pauses : 30min toutes les 3h pour consolidation

📚 STRATÉGIES ULTRA-SPÉCIFIQUES PAR MATIÈRE (NIVEAU ASIE-PACIFIQUE) :

MATHÉMATIQUES :
- Pré-cours (15min) : "Activation neuronale par calcul mental rapide + révision formules-clés"
- Post-cours immédiat (30min) : "Consolidation par 5-8 exercices types + mémorisation méthodes"
- J+1 (90min) : "Renforcement par variations d'exercices + approfondissement théorique"
- J+3 (75min) : "Intégration par problèmes complexes + liens avec physique"
- J+7 (60min) : "Maîtrise par exercices niveau supérieur + création de synthèses"

SCIENCES (Physique/Chimie/Biologie) :
- Pré-cours (20min) : "Activation par révision concepts + formules + expériences mentales"
- Post-cours (45min) : "Schématisation visuelle + dessins explicatifs + applications immédiates"
- J+1 (90min) : "Expériences virtuelles + résolution problèmes + liens interdisciplinaires"
- J+3 (75min) : "Cas pratiques réels + analogies créatives + débats scientifiques"
- J+7 (90min) : "Synthèse panoramique + préparation examens + projets personnels"

LANGUES (Français/Anglais) :
- Pré-cours (15min) : "Activation lexicale par lecture rapide + warm-up grammatical"
- Post-cours (30min) : "Production écrite immédiate + enrichissement vocabulaire ciblé"
- J+1 (75min) : "Expression orale + analyse littéraire + exercices créatifs"
- J+3 (90min) : "Rédaction longue + analyse comparative + débat argumenté"
- J+7 (60min) : "Synthèse culturelle + préparation exposés + lecture approfondie"

SCIENCES HUMAINES (Histoire/Géographie) :
- Pré-cours (20min) : "Contextualisation spatio-temporelle + activation connaissances"
- Post-cours (45min) : "Chronologies détaillées + cartes mentales + fiches personnages"
- J+1 (90min) : "Analyses causes-effets + comparaisons historiques + débats"
- J+3 (75min) : "Dissertations courtes + études de cas + liens actualité"
- J+7 (90min) : "Synthèses panoramiques + préparation examens + projets recherche"

🔧 RÈGLES D'OPTIMISATION ULTRA-STRICTES NIVEAU MONDIAL :

1. GESTION DES CRÉNEAUX LIBRES :
- 45-75min : Session d'approfondissement sur matière du cours précédent
- 75-120min : Travail intensif sur matière faible + révisions espacées
- 120min+ : Projet majeur + dissertation + préparation examens

2. DÉTECTION ET INTÉGRATION DES PAUSES VITALES :
- Pause déjeuner automatique si manquante (12h-13h30 minimum)
- Pauses actives (marche, exercices) intégrées automatiquement
- Temps de sommeil respecté (22h30 dernier apprentissage)

3. SUGGESTIONS LASER-PRECISION :
❌ INTERDIT : Termes vagues, durées < 45min pour apprentissage
✅ OBLIGATOIRE : Activités ultra-spécifiques avec matière, durée, méthode

Exemple PARFAIT :
- 14h30-16h00 (90min après cours Math 10h-12h) :
"MATHÉMATIQUES - Consolidation J+1 : Résolution de 12 équations du second degré (4 types différents) + mémorisation active discriminant par récitation + création fiche synthèse méthodes + 3 exercices défis niveau supérieur. Objectif : maîtrise complète chapitre équations."

4. INTERCONNEXIONS DISCIPLINAIRES INTELLIGENTES :
- Math ↔ Physique : Applications directes, formules communes
- Histoire ↔ Géographie : Contextes spatio-temporels
- Français ↔ Philosophie : Argumentation, analyse textuelle
- Sciences ↔ Mathématiques : Modélisation, statistiques

5. SYSTÈME DE PROGRESSION MESURABLE :
- Objectifs quotidiens précis et mesurables
- Évaluations hebdomadaires intégrées
- Ajustements automatiques selon résultats

🎯 MISSION CRITIQUE NIVEAU EXCELLENCE MONDIALE :
Transforme CHAQUE SECONDE en OPPORTUNITÉ D'EXCELLENCE ACADÉMIQUE.
Intègre automatiquement :
- Pauses déjeuner optimales (60-90min)
- Révisions espacées scientifiquement prouvées
- Activités de minimum 45min (sauf transitions)
- Respect des rythmes circadiens
- Charge cognitive équilibrée

EMPLOI DU TEMPS À RÉVOLUTIONNER :
${JSON.stringify(timetableData, null, 2)}

RÉSULTAT ATTENDU : 
JSON parfaitement structuré avec emploi du temps transformé en MACHINE À GÉNIE ACADÉMIQUE.
Chaque créneau libre devient un ACCÉLÉRATEUR DE PERFORMANCE MONDIALE.
Supprime toutes les incohérences, ajoute les pauses vitales, optimise chaque minute.

IMPÉRATIF : Aucun caractère bizarre, aucune durée < 45min pour l'apprentissage, pauses déjeuner obligatoires, révisions espacées intégrées.

FORMAT : JSON identique à l'input, avec tous les créneaux libres transformés en sessions d'excellence.`;
}

function generateTimeSlots(startHour, endHour, intervalMinutes = 15) {
    const slots = [];
    for (let hour = startHour; hour <= endHour; hour++) {
        for (let minute = 0; minute < 60; minute += intervalMinutes) {
            slots.push(hour * 60 + minute);
        }
    }
    return slots;
}

function timeToMinutes(timeString) {
    const [hours, minutes] = timeString.split(':').map(Number);
    return hours * 60 + minutes;
}

function minutesToTime(minutes) {
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`;
}

function analyzeSubjectDistribution(activities) {
    const subjects = {};
    activities.forEach(activity => {
        const subject = activity.activity.toLowerCase();
        if (!subjects[subject]) subjects[subject] = 0;
        subjects[subject] += timeToMinutes(activity.endTime) - timeToMinutes(activity.startTime);
    });
    return subjects;
}

function calculateCognitiveLoad(activities) {
    const cognitiveWeights = {
        'math': 10, 'mathématiques': 10,
        'physique': 9, 'physics': 9,
        'chimie': 8, 'chemistry': 8,
        'français': 6, 'french': 6,
        'anglais': 6, 'english': 6,
        'histoire': 5, 'history': 5,
        'géographie': 5, 'geography': 5,
        'biologie': 7, 'biology': 7
    };
    
    const hourlyLoad = {};
    activities.forEach(activity => {
        const start = Math.floor(timeToMinutes(activity.startTime) / 60);
        const end = Math.ceil(timeToMinutes(activity.endTime) / 60);
        
        const subject = activity.activity.toLowerCase();
        const weight = cognitiveWeights[subject] || 5;
        
        for (let hour = start; hour < end; hour++) {
            hourlyLoad[hour] = (hourlyLoad[hour] || 0) + weight;
        }
    });
    
    return hourlyLoad;
}

function analyzeWeeklyPatterns(timetableData) {
    const patterns = {
        heavyDays: [],
        lightDays: [],
        subjectFrequency: {},
        optimalDistribution: {}
    };
    
    const days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    
    days.forEach(day => {
        const activities = timetableData[day] || [];
        const totalMinutes = activities.reduce((sum, activity) => {
            return sum + (timeToMinutes(activity.endTime) - timeToMinutes(activity.startTime));
        }, 0);
        
        if (totalMinutes > 480) patterns.heavyDays.push(day);
        if (totalMinutes < 240) patterns.lightDays.push(day);
    });
    
    return patterns;
}

exports.optimizeSchedule = onDocumentWritten(
    {
        document: "user_timetables/{userId}",
    },
    async (event) => {
        const userId = event.params.userId;
        const rawTimetableData = event.data?.after?.data();

        if (!rawTimetableData) {
            console.log("No data associated with the event");
            return null;
        }

        console.log(`🚀 OPTIMISATION NIVEAU MONDIAL pour utilisateur: ${userId}`);
        console.log("📊 Données brutes:", JSON.stringify(rawTimetableData));

        const timetableData = normalizeTimetableData(rawTimetableData);
        console.log("✅ Données normalisées:", JSON.stringify(timetableData));

        const deepAnalysis = analyzeScheduleGapsAndPatterns(timetableData);
        console.log("🧠 Analyse ultra-profonde:", JSON.stringify(deepAnalysis));

        try {
            const model = genAI.getGenerativeModel({
                model: "gemini-2.0-flash",
                generationConfig: {
                    temperature: 0.3,
                    topK: 20,
                    topP: 0.8,
                    maxOutputTokens: 8192,
                },
            });

            const worldClassPrompt = generateWorldClassPrompt(timetableData, deepAnalysis);
            console.log("🌍 Prompt niveau mondial généré");

            const result = await model.generateContent(worldClassPrompt);
            const response = await result.response;

            let optimizedScheduleJsonString = response.text();
            console.log("🤖 Réponse brute de Gemini:", optimizedScheduleJsonString);

            optimizedScheduleJsonString = optimizedScheduleJsonString
                .replace(/^```json\s*/, '')
                .replace(/^```\s*/, '')
                .replace(/\s*```$/, '')
                .replace(/[\u0000-\u001F\u007F-\u009F]/g, '')
                .replace(/[jJ]\b/g, '') // Supprimer les "j" ou "J" isolés
                .trim();

            const jsonMatch = optimizedScheduleJsonString.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                optimizedScheduleJsonString = jsonMatch[0];
            }

            console.log("🔧 JSON nettoyé:", optimizedScheduleJsonString);

            let optimizedScheduleData;
            try {
                optimizedScheduleData = JSON.parse(optimizedScheduleJsonString);
                
                if (!validateOptimizedSchedule(optimizedScheduleData)) {
                    throw new Error("Schedule validation failed");
                }
                
            } catch (parseError) {
                console.error("❌ Erreur de parsing JSON:", parseError);
                console.error("String problématique:", optimizedScheduleJsonString);
                
                optimizedScheduleData = createFallbackOptimizedSchedule(timetableData, deepAnalysis);
                console.log("🔄 Fallback intelligent activé");
            }

            const validatedData = normalizeTimetableData(optimizedScheduleData);
            
            const finalData = {
                ...validatedData,
                _metadata: {
                    optimizedAt: new Date().toISOString(),
                    optimizationLevel: 'world-class',
                    analysisUsed: deepAnalysis,
                    version: '2.0-pro'
                }
            };
            
            console.log("✅ Données validées niveau mondial:", JSON.stringify(finalData));

            const optimizedScheduleRef = admin.firestore()
                .collection("optimized_schedules")
                .doc(userId);
            
            await optimizedScheduleRef.set(finalData);

            console.log(`🎯 OPTIMISATION NIVEAU MONDIAL TERMINÉE pour utilisateur: ${userId}`);
            console.log("🏆 Emploi du temps de classe mondiale sauvegardé !");

            return null;
        } catch (error) {
            console.error("💥 Erreur lors de l'optimisation niveau mondial:", error);
            
            const fallbackData = createFallbackOptimizedSchedule(timetableData, deepAnalysis);
            
            const optimizedScheduleRef = admin.firestore()
                .collection("optimized_schedules")
                .doc(userId);
            
            await optimizedScheduleRef.set(fallbackData);
            console.log("🔄 Fallback sauvegardé avec succès");
            
            return null;
        }
    }
);

function validateOptimizedSchedule(scheduleData) {
    const days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    
    for (const day of days) {
        if (!scheduleData[day] || !Array.isArray(scheduleData[day])) {
            return false;
        }
        
        for (const activity of scheduleData[day]) {
            if (!activity.startTime || !activity.endTime || !activity.activity) {
                return false;
            }
            
            if (!/^\d{2}:\d{2}$/.test(activity.startTime) || !/^\d{2}:\d{2}$/.test(activity.endTime)) {
                return false;
            }
        }
    }
    
    return true;
}

function createFallbackOptimizedSchedule(originalSchedule, analysis) {
    const optimized = JSON.parse(JSON.stringify(originalSchedule));
    
    const days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    
    days.forEach(day => {
        if (!optimized[day]) optimized[day] = [];
        
        const hasLunch = optimized[day].some(activity => {
            const start = timeToMinutes(activity.startTime);
            const end = timeToMinutes(activity.endTime);
            return start <= 12*60 + 30 && end >= 12*60;
        });
        
        if (!hasLunch) {
            optimized[day].push({
                startTime: "12:00",
                endTime: "13:00",
                activity: "Pause déjeuner - Récupération neuronale essentielle",
                type: "break",
                priority: "essential"
            });
        }
        
        optimized[day].sort((a, b) => timeToMinutes(a.startTime) - timeToMinutes(b.startTime));
    });
    
    return optimized;
}
