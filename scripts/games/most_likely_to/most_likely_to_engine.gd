extends RefCounted

## Most Likely To: read a card ("Who's most likely to..."), everyone counts to
## three and points at someone; whoever gets the most fingers drinks. Two
## decks (mild / spicy -- cheeky, never explicit) in English and Spanish,
## dealt from a shuffled bag so none repeats until the deck runs out.

const MILD := [
	"Who's most likely to become famous?",
	"Who's most likely to forget their own birthday?",
	"Who's most likely to survive a zombie apocalypse?",
	"Who's most likely to cry at a commercial?",
	"Who's most likely to become a millionaire?",
	"Who's most likely to get lost on the way here?",
	"Who's most likely to adopt ten cats?",
	"Who's most likely to win a reality show?",
	"Who's most likely to laugh at the wrong moment?",
	"Who's most likely to move to another country?",
	"Who's most likely to fall asleep at a party?",
	"Who's most likely to start a business?",
	"Who's most likely to be late to their own wedding?",
	"Who's most likely to eat something off the floor?",
	"Who's most likely to talk their way out of a speeding ticket?",
	"Who's most likely to become a teacher?",
	"Who's most likely to spend all their money in one day?",
	"Who's most likely to trip over nothing?",
	"Who's most likely to know all the lyrics?",
	"Who's most likely to cheat at a board game?",
	"Who's most likely to go viral online?",
	"Who's most likely to forget where they parked?",
	"Who's most likely to become a president?",
	"Who's most likely to start a fight over pizza toppings?",
	"Who's most likely to binge a whole series in one night?",
	"Who's most likely to get a tattoo they regret?",
	"Who's most likely to talk to plants?",
	"Who's most likely to live to 100?",
	"Who's most likely to be a secret genius?",
	"Who's most likely to sing karaoke without being asked?",
	"Who's most likely to lose their phone tonight?",
	"Who's most likely to burn water while cooking?",
	"Who's most likely to become an influencer?",
	"Who's most likely to scream at a scary movie?",
	"Who's most likely to forget why they walked into a room?",
	"Who's most likely to plan a surprise party?",
	"Who's most likely to have a hidden talent?",
	"Who's most likely to quit their job to travel the world?",
	"Who's most likely to win an argument with a lawyer?",
	"Who's most likely to keep a secret forever?",
]
const SPICY := [
	"Who's most likely to text their ex tonight?",
	"Who's most likely to fall in love on vacation?",
	"Who's most likely to have a secret crush in this room?",
	"Who's most likely to kiss a stranger?",
	"Who's most likely to get married first?",
	"Who's most likely to go on three dates in one week?",
	"Who's most likely to flirt with the waiter?",
	"Who's most likely to have the most exes?",
	"Who's most likely to dance on a table?",
	"Who's most likely to get back with an ex?",
	"Who's most likely to fall for someone in one night?",
	"Who's most likely to forget a date's name?",
	"Who's most likely to have a dating app open right now?",
	"Who's most likely to send a risky text and regret it?",
	"Who's most likely to wake up somewhere unexpected?",
	"Who's most likely to start a rumor?",
	"Who's most likely to lie about where they were last night?",
	"Who's most likely to get kicked out of a party?",
	"Who's most likely to propose on the first month?",
	"Who's most likely to have a secret relationship?",
	"Who's most likely to break a heart this year?",
	"Who's most likely to sneak out of a party without saying goodbye?",
	"Who's most likely to be the last one standing tonight?",
	"Who's most likely to call someone by the wrong name?",
	"Who's most likely to fall asleep first tonight?",
]

const MILD_ES := [
	"¿Quién es más probable que se haga famoso?",
	"¿Quién es más probable que olvide su propio cumpleaños?",
	"¿Quién es más probable que sobreviva a un apocalipsis zombi?",
	"¿Quién es más probable que llore con un comercial?",
	"¿Quién es más probable que se haga millonario?",
	"¿Quién es más probable que se haya perdido viniendo hasta aquí?",
	"¿Quién es más probable que adopte diez gatos?",
	"¿Quién es más probable que gane un reality show?",
	"¿Quién es más probable que se ría en el peor momento?",
	"¿Quién es más probable que se mude a otro país?",
	"¿Quién es más probable que se duerma en una fiesta?",
	"¿Quién es más probable que ponga su propio negocio?",
	"¿Quién es más probable que llegue tarde a su propia boda?",
	"¿Quién es más probable que coma algo del piso?",
	"¿Quién es más probable que se salve de una multa hablando?",
	"¿Quién es más probable que termine siendo profesor?",
	"¿Quién es más probable que se gaste todo su dinero en un día?",
	"¿Quién es más probable que se tropiece con nada?",
	"¿Quién es más probable que se sepa todas las letras?",
	"¿Quién es más probable que haga trampa en un juego de mesa?",
	"¿Quién es más probable que se haga viral en internet?",
	"¿Quién es más probable que olvide dónde estacionó?",
	"¿Quién es más probable que llegue a presidente?",
	"¿Quién es más probable que se pelee por los ingredientes de la pizza?",
	"¿Quién es más probable que vea una serie entera en una noche?",
	"¿Quién es más probable que se haga un tatuaje del que se arrepienta?",
	"¿Quién es más probable que les hable a las plantas?",
	"¿Quién es más probable que viva hasta los 100?",
	"¿Quién es más probable que sea un genio en secreto?",
	"¿Quién es más probable que cante karaoke sin que se lo pidan?",
	"¿Quién es más probable que pierda el celular esta noche?",
	"¿Quién es más probable que queme el agua cocinando?",
	"¿Quién es más probable que se haga influencer?",
	"¿Quién es más probable que grite con una película de terror?",
	"¿Quién es más probable que olvide a qué entró a una habitación?",
	"¿Quién es más probable que organice una fiesta sorpresa?",
	"¿Quién es más probable que tenga un talento oculto?",
	"¿Quién es más probable que renuncie para viajar por el mundo?",
	"¿Quién es más probable que le gane una discusión a un abogado?",
	"¿Quién es más probable que guarde un secreto para siempre?",
]
const SPICY_ES := [
	"¿Quién es más probable que le escriba a su ex esta noche?",
	"¿Quién es más probable que se enamore en las vacaciones?",
	"¿Quién es más probable que tenga un crush secreto en esta sala?",
	"¿Quién es más probable que bese a un desconocido?",
	"¿Quién es más probable que se case primero?",
	"¿Quién es más probable que tenga tres citas en una semana?",
	"¿Quién es más probable que le coquetee al mesero?",
	"¿Quién es más probable que tenga más ex?",
	"¿Quién es más probable que baile arriba de una mesa?",
	"¿Quién es más probable que vuelva con su ex?",
	"¿Quién es más probable que se enamore en una sola noche?",
	"¿Quién es más probable que olvide el nombre de su cita?",
	"¿Quién es más probable que tenga una app de citas abierta ahora mismo?",
	"¿Quién es más probable que mande un mensaje arriesgado y se arrepienta?",
	"¿Quién es más probable que despierte en un lugar inesperado?",
	"¿Quién es más probable que empiece un chisme?",
	"¿Quién es más probable que mienta sobre dónde estuvo anoche?",
	"¿Quién es más probable que lo echen de una fiesta?",
	"¿Quién es más probable que proponga matrimonio al primer mes?",
	"¿Quién es más probable que tenga una relación en secreto?",
	"¿Quién es más probable que rompa un corazón este año?",
	"¿Quién es más probable que se vaya de una fiesta sin despedirse?",
	"¿Quién es más probable que sea el último en pie esta noche?",
	"¿Quién es más probable que llame a alguien por el nombre equivocado?",
	"¿Quién es más probable que se duerma primero esta noche?",
]

## deck: "mild", "spicy" or "mixed"
var deck := "mild"
var spanish := false
var bag: Array = []
var current := ""
var dealt := 0

func reset(p_deck: String, p_spanish: bool) -> void:
	deck = p_deck
	spanish = p_spanish
	bag = []
	current = ""
	dealt = 0

func cards() -> Array:
	var mild: Array = MILD_ES if spanish else MILD
	var spicy: Array = SPICY_ES if spanish else SPICY
	match deck:
		"spicy":
			return spicy
		"mixed":
			return mild + spicy
	return mild

## Deals the next prompt (the bag refills, reshuffled, when it runs out).
func next_card() -> String:
	if bag.is_empty():
		bag = cards().duplicate()
		bag.shuffle()
		if bag.size() > 1 and bag.back() == current:
			bag.reverse()  # never the same card twice in a row across a refill
	current = bag.pop_back()
	dealt += 1
	return current
