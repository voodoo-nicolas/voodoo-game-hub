extends RefCounted

## Never Have I Ever: a deck of prompts read out loud, one per turn. Anyone
## who HAS done it drinks. Two decks (mild / spicy -- flirty, never explicit)
## in English and Spanish; cards are dealt from a shuffled bag, so none
## repeats until the whole deck has come up. Pure logic, no Nodes.

const MILD := [
	"Never have I ever sung in the shower.",
	"Never have I ever fallen asleep in class or at work.",
	"Never have I ever pretended to laugh at a joke I didn't get.",
	"Never have I ever eaten food that fell on the floor.",
	"Never have I ever cried during a movie.",
	"Never have I ever sent a text to the wrong person.",
	"Never have I ever forgotten someone's name right after meeting them.",
	"Never have I ever stalked an ex on social media.",
	"Never have I ever lied about my age.",
	"Never have I ever binge-watched a whole series in one weekend.",
	"Never have I ever been on TV.",
	"Never have I ever broken a bone.",
	"Never have I ever gotten lost in my own city.",
	"Never have I ever talked to a pet like it was a person.",
	"Never have I ever re-gifted a present.",
	"Never have I ever walked into a glass door.",
	"Never have I ever laughed so hard I cried.",
	"Never have I ever pretended to be sick to skip something.",
	"Never have I ever eaten a whole pizza by myself.",
	"Never have I ever dyed my hair a crazy color.",
	"Never have I ever missed a flight.",
	"Never have I ever been to a concert alone.",
	"Never have I ever cheated at a board game.",
	"Never have I ever tripped in public and pretended it didn't happen.",
	"Never have I ever waved back at someone who wasn't waving at me.",
	"Never have I ever read someone else's messages over their shoulder.",
	"Never have I ever forgotten a friend's birthday.",
	"Never have I ever sleep-talked or sleepwalked.",
	"Never have I ever lost my phone while it was in my hand.",
	"Never have I ever googled myself.",
	"Never have I ever stayed awake for more than 24 hours.",
	"Never have I ever pretended to know a song and made up the words.",
	"Never have I ever ridden a horse.",
	"Never have I ever gone a whole day without my phone.",
	"Never have I ever blamed a smell on someone else.",
	"Never have I ever been kicked out of a class.",
	"Never have I ever practiced a speech in the mirror.",
	"Never have I ever been stuck in an elevator.",
	"Never have I ever eaten breakfast for dinner.",
	"Never have I ever laughed at a funeral.",
	"Never have I ever said \"I love you\" first.",
	"Never have I ever cut my own hair.",
	"Never have I ever had a crush on a teacher.",
	"Never have I ever slid into someone's DMs.",
	"Never have I ever pretended to be on the phone to avoid someone.",
]
const SPICY := [
	"Never have I ever kissed someone in this room.",
	"Never have I ever had a crush on a friend's partner.",
	"Never have I ever gone on a blind date.",
	"Never have I ever kissed someone on the first date.",
	"Never have I ever been dumped by text.",
	"Never have I ever dumped someone by text.",
	"Never have I ever lied in the \"Never have I ever\" game.",
	"Never have I ever used a dating app.",
	"Never have I ever had a secret relationship.",
	"Never have I ever flirted to get out of trouble.",
	"Never have I ever sent a flirty message and regretted it.",
	"Never have I ever kissed two people in one night.",
	"Never have I ever had a crush on someone in this room.",
	"Never have I ever gone back to an ex.",
	"Never have I ever been caught checking someone out.",
	"Never have I ever pretended to like someone's gift to impress them.",
	"Never have I ever skinny-dipped.",
	"Never have I ever woken up not knowing where I was.",
	"Never have I ever danced on a table.",
	"Never have I ever lied to get out of a date.",
	"Never have I ever been in love with two people at once.",
	"Never have I ever forgotten the name of someone I was dating.",
	"Never have I ever had a holiday romance.",
	"Never have I ever kissed a stranger.",
	"Never have I ever stood someone up.",
	"Never have I ever had a crush on a celebrity for years.",
	"Never have I ever written a love letter.",
	"Never have I ever been the third wheel on a date.",
	"Never have I ever drunk-texted an ex.",
	"Never have I ever sneaked out of the house at night.",
]

const MILD_ES := [
	"Yo nunca nunca he cantado en la ducha.",
	"Yo nunca nunca me he quedado dormido en clase o en el trabajo.",
	"Yo nunca nunca me he reído de un chiste que no entendí.",
	"Yo nunca nunca he comido algo que se cayó al piso.",
	"Yo nunca nunca he llorado viendo una película.",
	"Yo nunca nunca le he mandado un mensaje a la persona equivocada.",
	"Yo nunca nunca he olvidado el nombre de alguien justo después de conocerlo.",
	"Yo nunca nunca he espiado a mi ex en redes sociales.",
	"Yo nunca nunca he mentido sobre mi edad.",
	"Yo nunca nunca he visto una serie entera en un fin de semana.",
	"Yo nunca nunca he salido en la tele.",
	"Yo nunca nunca me he roto un hueso.",
	"Yo nunca nunca me he perdido en mi propia ciudad.",
	"Yo nunca nunca le he hablado a una mascota como si fuera una persona.",
	"Yo nunca nunca he regalado algo que me regalaron.",
	"Yo nunca nunca me he chocado contra una puerta de vidrio.",
	"Yo nunca nunca me he reído tanto que lloré.",
	"Yo nunca nunca me he hecho el enfermo para no ir a algo.",
	"Yo nunca nunca me he comido una pizza entera yo solo.",
	"Yo nunca nunca me he teñido el pelo de un color loco.",
	"Yo nunca nunca he perdido un vuelo.",
	"Yo nunca nunca he ido solo a un concierto.",
	"Yo nunca nunca he hecho trampa en un juego de mesa.",
	"Yo nunca nunca me he tropezado en público y disimulado.",
	"Yo nunca nunca he saludado a alguien que no me estaba saludando a mí.",
	"Yo nunca nunca he leído los mensajes de otro por encima del hombro.",
	"Yo nunca nunca me he olvidado del cumpleaños de un amigo.",
	"Yo nunca nunca he hablado o caminado dormido.",
	"Yo nunca nunca he buscado mi celular teniéndolo en la mano.",
	"Yo nunca nunca me he buscado a mí mismo en Google.",
	"Yo nunca nunca he estado más de 24 horas sin dormir.",
	"Yo nunca nunca he cantado una canción inventando la letra.",
	"Yo nunca nunca he montado a caballo.",
	"Yo nunca nunca he pasado un día entero sin celular.",
	"Yo nunca nunca le he echado la culpa de un olor a otro.",
	"Yo nunca nunca me han echado de una clase.",
	"Yo nunca nunca he ensayado un discurso frente al espejo.",
	"Yo nunca nunca me he quedado atrapado en un ascensor.",
	"Yo nunca nunca he desayunado a la hora de la cena.",
	"Yo nunca nunca me he reído en un velorio.",
	"Yo nunca nunca he dicho \"te quiero\" primero.",
	"Yo nunca nunca me he cortado el pelo yo mismo.",
	"Yo nunca nunca me he enamorado de un profesor.",
	"Yo nunca nunca le he escrito por privado a alguien para ligar.",
	"Yo nunca nunca he fingido hablar por teléfono para evitar a alguien.",
]
const SPICY_ES := [
	"Yo nunca nunca he besado a alguien de esta sala.",
	"Yo nunca nunca me ha gustado la pareja de un amigo.",
	"Yo nunca nunca he ido a una cita a ciegas.",
	"Yo nunca nunca he besado a alguien en la primera cita.",
	"Yo nunca nunca me han dejado por mensaje.",
	"Yo nunca nunca he dejado a alguien por mensaje.",
	"Yo nunca nunca he mentido jugando al \"Yo nunca nunca\".",
	"Yo nunca nunca he usado una app de citas.",
	"Yo nunca nunca he tenido una relación en secreto.",
	"Yo nunca nunca he coqueteado para salir de un problema.",
	"Yo nunca nunca he mandado un mensaje coqueto y me arrepentí.",
	"Yo nunca nunca he besado a dos personas en una misma noche.",
	"Yo nunca nunca me ha gustado alguien de esta sala.",
	"Yo nunca nunca he vuelto con un ex.",
	"Yo nunca nunca me han pillado mirando a alguien.",
	"Yo nunca nunca he fingido que me gustaba un regalo para impresionar.",
	"Yo nunca nunca me he bañado desnudo.",
	"Yo nunca nunca me he despertado sin saber dónde estaba.",
	"Yo nunca nunca he bailado arriba de una mesa.",
	"Yo nunca nunca he mentido para zafarme de una cita.",
	"Yo nunca nunca he estado enamorado de dos personas a la vez.",
	"Yo nunca nunca he olvidado el nombre de alguien con quien salía.",
	"Yo nunca nunca he tenido un romance de vacaciones.",
	"Yo nunca nunca he besado a un desconocido.",
	"Yo nunca nunca he dejado plantado a alguien.",
	"Yo nunca nunca he estado enamorado de un famoso durante años.",
	"Yo nunca nunca he escrito una carta de amor.",
	"Yo nunca nunca he sido el mal tercio en una cita.",
	"Yo nunca nunca le he escrito borracho a mi ex.",
	"Yo nunca nunca me he escapado de casa de noche.",
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
