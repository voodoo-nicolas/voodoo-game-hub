// Hand-written banks and story text for the second INT set (gens/int2.ts), 2026-10-25. NOT from
// the prototype; ideas from the IQ Question Lab (several are Heather's). Three tiers (d 1-3,
// 4-7, 8-10); EN and ES (rioplatense, voseo). Every item must have exactly one best answer:
// a human reads new items before they ship (meaning can't be machine-checked).

import type { Lang } from "./registry.ts";
import type { Tiers } from "./lin2_data.ts";

/** feel / change / help: [story ("" = none), question, best answer, wrong x3, why the answer
 *  is best (shown after a practice answer; owner, 2026-10-25)] */
export type Story4 = [string, string, string, string[], string];

export const FEEL: { en: Tiers<Story4>; es: Tiers<Story4> } = {
  en: [
    [
      ["Sam trained for months for a marathon. The day before the race, it is cancelled for good.", "How does Sam most likely feel?", "Disappointed", ["Guilty", "Embarrassed", "Jealous"], "Months of training lead to a race that will never happen: losing something you worked for brings disappointment. Nobody did anything wrong (no guilt), nothing embarrassing happened and nobody got what Sam wanted (no jealousy)."],
      ["Mia's lost dog is found and brought home safe after three days.", "How does Mia most likely feel?", "Relieved", ["Bored", "Ashamed", "Jealous"], "Three days of worry end well. When a fear is lifted, the feeling is relief."],
      ["Leo opens a present and finds the bike he had wanted all year.", "How does Leo most likely feel?", "Delighted", ["Lonely", "Guilty", "Afraid"], "He got exactly what he had wished for all year, which brings delight."],
      ["Ana hears a loud crash downstairs in the middle of the night. She is home alone.", "How does Ana most likely feel?", "Frightened", ["Proud", "Bored", "Grateful"], "A loud crash at night while she is alone suggests danger, and danger brings fear."],
      ["Tom's best friend moves to another country, and Tom won't see his friend for years.", "How does Tom most likely feel?", "Sad", ["Proud", "Embarrassed", "Amused"], "Not seeing his best friend for years is a loss, and a loss brings sadness."],
    ],
    [
      ["In front of the whole class, Nora trips and drops her lunch tray.", "How does Nora most likely feel?", "Embarrassed", ["Guilty", "Jealous", "Grateful"], "A clumsy moment in front of everyone, with no harm done to anyone, brings embarrassment. Guilt would need her to have wronged someone."],
      ["Raúl broke his sister's phone by accident and let her think the dog did it.", "How does Raúl most likely feel?", "Guilty", ["Proud", "Relieved", "Jealous"], "He broke something and let someone else take the blame. Knowing you did something wrong brings guilt."],
      ["Eva's friend gets the part in the play that Eva wanted, and everyone is congratulating her friend.", "How does Eva most likely feel?", "Jealous", ["Guilty", "Relieved", "Ashamed"], "Someone else got the part Eva wanted, and is being praised for it: that is jealousy."],
      ["After weeks of worrying, Ben learns that the lump the doctor found is harmless.", "How does Ben most likely feel?", "Relieved", ["Proud", "Jealous", "Guilty"], "A long worry turns out to be unfounded, so the feeling is relief."],
      ["Lucía has her first job interview tomorrow and keeps checking her notes.", "How does Lucía most likely feel?", "Nervous", ["Guilty", "Jealous", "Bored"], "Something important is happening for the first time tomorrow, and she keeps checking her notes: she is nervous."],
    ],
    [
      ["Clara is moving abroad for her dream job. At the airport she hugs her family goodbye.", "How does Clara most likely feel?", "Excited and sad at the same time", ["Only excited", "Only sad", "Angry with her family"], "The dream job is exciting, but leaving her family is sad. Big changes often bring both feelings at once."],
      ["Diego's team wins the final, but Diego spent the whole match on the bench.", "How does Diego most likely feel?", "Happy for the team, but left out", ["Only happy", "Guilty about the win", "Angry with the other team"], "His team won, which is good news, but he didn't get to play. He can be glad and feel left out at the same time."],
      ["Iris lent money to a friend who never paid it back. Now the friend posts photos from an expensive holiday.", "How does Iris most likely feel?", "Resentful", ["Grateful", "Guilty", "Proud of her friend"], "The friend has money for luxuries but never paid her back. Feeling treated unfairly by someone, and holding on to it, is resentment."],
      ["Pablo beats his older brother at chess for the first time ever. His brother looks upset.", "How does Pablo most likely feel?", "Proud, but a little sorry for his brother", ["Only guilty", "Bored", "Ashamed of winning"], "Beating his big brother for the first time makes him proud, and seeing his brother upset makes him feel a little sorry."],
      ["Marta's grandmother was very ill and in pain for a long time. Yesterday she died.", "How does Marta most likely feel?", "Sad, with some relief that the pain is over", ["Only relieved", "Guilty", "Indifferent"], "Losing her grandmother is sad, but her long suffering has ended, so relief is mixed in. Feeling both is normal, not a reason for guilt."],
    ],
  ],
  es: [
    [
      ["Sam entrenó meses para una maratón. El día antes, la cancelan para siempre.", "¿Cómo se siente Sam, lo más probable?", "Desilusionado", ["Culpable", "Avergonzado", "Celoso"], "Meses de entrenamiento para una carrera que nunca se va a correr: perder algo por lo que trabajaste da desilusión. Nadie hizo nada malo (no hay culpa), no pasó nada vergonzoso y nadie consiguió lo que Sam quería (no hay celos)."],
      ["Después de tres días, encuentran al perro perdido de Mía y lo traen sano a casa.", "¿Cómo se siente Mía, lo más probable?", "Aliviada", ["Aburrida", "Avergonzada", "Celosa"], "Tres días de preocupación terminan bien. Cuando un miedo desaparece, lo que se siente es alivio."],
      ["Leo abre un regalo y es la bici que quería desde hacía un año.", "¿Cómo se siente Leo, lo más probable?", "Encantado", ["Solo", "Culpable", "Asustado"], "Recibió justo lo que deseaba desde hacía un año, y eso da alegría: está encantado."],
      ["Ana escucha un golpe fuerte abajo en medio de la noche. Está sola en casa.", "¿Cómo se siente Ana, lo más probable?", "Asustada", ["Orgullosa", "Aburrida", "Agradecida"], "Un golpe fuerte de noche, estando sola, hace pensar en un peligro, y el peligro da miedo."],
      ["El mejor amigo de Tomás se muda a otro país, y no se van a ver en años.", "¿Cómo se siente Tomás, lo más probable?", "Triste", ["Orgulloso", "Avergonzado", "Divertido"], "No ver a su mejor amigo durante años es una pérdida, y las pérdidas dan tristeza."],
    ],
    [
      ["Delante de toda la clase, Nora se tropieza y se le cae la bandeja del almuerzo.", "¿Cómo se siente Nora, lo más probable?", "Avergonzada", ["Culpable", "Celosa", "Agradecida"], "Un momento torpe delante de todos, sin dañar a nadie, da vergüenza. Para sentir culpa tendría que haberle hecho algo malo a alguien."],
      ["Raúl rompió sin querer el celular de su hermana y la dejó creer que había sido el perro.", "¿Cómo se siente Raúl, lo más probable?", "Culpable", ["Orgulloso", "Aliviado", "Celoso"], "Rompió algo y dejó que culparan a otro. Saber que hiciste algo mal da culpa."],
      ["Una amiga de Eva consigue el papel de la obra que Eva quería, y todos la felicitan.", "¿Cómo se siente Eva, lo más probable?", "Celosa", ["Culpable", "Aliviada", "Avergonzada"], "Otra persona consiguió el papel que Eva quería y encima la felicitan: eso son celos."],
      ["Después de semanas de preocupación, Beto se entera de que el bulto que le encontró el médico no es nada grave.", "¿Cómo se siente Beto, lo más probable?", "Aliviado", ["Orgulloso", "Celoso", "Culpable"], "Una preocupación larga resulta no tener motivo, así que lo que siente es alivio."],
      ["Lucía tiene mañana su primera entrevista de trabajo y repasa sus notas una y otra vez.", "¿Cómo se siente Lucía, lo más probable?", "Nerviosa", ["Culpable", "Celosa", "Aburrida"], "Mañana le pasa algo importante por primera vez y repasa sus notas una y otra vez: está nerviosa."],
    ],
    [
      ["Clara se va a vivir afuera por el trabajo de sus sueños. En el aeropuerto abraza a su familia para despedirse.", "¿Cómo se siente Clara, lo más probable?", "Entusiasmada y triste a la vez", ["Solo entusiasmada", "Solo triste", "Enojada con su familia"], "El trabajo soñado entusiasma, pero dejar a la familia entristece. Los grandes cambios suelen traer los dos sentimientos a la vez."],
      ["El equipo de Diego gana la final, pero Diego pasó todo el partido en el banco.", "¿Cómo se siente Diego, lo más probable?", "Contento por el equipo, pero dejado de lado", ["Solo contento", "Culpable por haber ganado", "Enojado con el otro equipo"], "Su equipo ganó, que es una buena noticia, pero él no jugó. Puede estar contento y sentirse dejado de lado al mismo tiempo."],
      ["Iris le prestó plata a una amiga que nunca se la devolvió. Ahora la amiga sube fotos de unas vacaciones carísimas.", "¿Cómo se siente Iris, lo más probable?", "Resentida", ["Agradecida", "Culpable", "Orgullosa de su amiga"], "La amiga tiene plata para lujos pero nunca le devolvió lo que le debe. Sentir que alguien te trató injustamente, y no soltarlo, es resentimiento."],
      ["Pablo le gana al ajedrez a su hermano mayor por primera vez en la vida. El hermano parece dolido.", "¿Cómo se siente Pablo, lo más probable?", "Orgulloso, pero un poco mal por su hermano", ["Solo culpable", "Aburrido", "Avergonzado de haber ganado"], "Ganarle por primera vez a su hermano mayor lo enorgullece, y ver a su hermano dolido lo hace sentir un poco mal."],
      ["La abuela de Marta estuvo muy enferma y con dolores mucho tiempo. Ayer murió.", "¿Cómo se siente Marta, lo más probable?", "Triste, con algo de alivio porque terminó el dolor", ["Solo aliviada", "Culpable", "Indiferente"], "Perder a su abuela es triste, pero su largo sufrimiento terminó, así que también hay alivio. Sentir las dos cosas es normal, no es motivo de culpa."],
    ],
  ],
};

export const CHANGE: { en: Tiers<Story4>; es: Tiers<Story4> } = {
  en: [
    [
      ["", "Annoyance that keeps building, with no way to let it out, most often turns into…", "Rage", ["Boredom", "Pride", "Relief"], "Annoyance is a mild kind of anger. If it keeps building with no way out, it grows into rage."],
      ["", "Worry that keeps growing usually becomes…", "Panic", ["Joy", "Pride", "Boredom"], "Worry is a kind of fear. Fear at its most intense is panic."],
      ["", "When something you feared doesn't happen after all, you usually feel…", "Relief", ["Guilt", "Jealousy", "Shame"], "Relief is what you feel when something you feared doesn't happen."],
      ["", "Contentment that grows stronger can become…", "Joy", ["Anger", "Fear", "Guilt"], "Joy is the same pleasant feeling as contentment, only stronger."],
      ["", "Sadness that lasts a long time and won't lift can turn into…", "Despair", ["Pride", "Surprise", "Excitement"], "Sadness that lasts and won't lift takes away hope, and that turns into despair."],
    ],
    [
      ["Someone feels relieved when a problem is solved, then learns it was solved by a friend they had blamed for it.", "What feeling most likely comes next?", "Guilt", ["Pride", "Jealousy", "Boredom"], "They had blamed the very friend who solved the problem. Realising you treated someone unfairly brings guilt."],
      ["Someone is excited about a party, then hears that nobody else is going.", "What feeling most likely comes next?", "Disappointment", ["Relief", "Pride", "Guilt"], "Something they looked forward to falls through, which brings disappointment."],
      ["Someone is afraid of failing an exam, studies hard and passes with top marks.", "What feeling most likely comes next?", "Pride", ["Shame", "Jealousy", "Guilt"], "They worked hard and it paid off. Success after effort brings pride."],
      ["Someone is pleased with a gift, then finds out the giver forgot their birthday and grabbed it at the last minute.", "What feeling most likely comes next?", "Disappointment", ["Pride", "Relief", "Fear"], "The gift seemed thoughtful but was a last-minute afterthought. Learning you mattered less than you thought brings disappointment."],
      ["Someone is surprised by a knock at the door late at night, then sees a stranger outside acting oddly.", "What feeling most likely comes next?", "Fear", ["Joy", "Pride", "Boredom"], "The surprise turns into fear once the surprise looks like possible danger."],
    ],
    [
      ["Someone is jealous of a friend's success, then sees how hard the friend worked for it.", "What feeling most likely replaces the jealousy?", "Admiration", ["Contempt", "Fear", "Disgust"], "Seeing the hard work behind the success shows it was earned, so jealousy gives way to admiration."],
      ["Someone is angry with a coworker for a mistake, then finds out the coworker was covering for them.", "What feeling most likely replaces the anger?", "Gratitude mixed with guilt", ["Pride", "Contempt", "Boredom"], "The coworker was protecting them: grateful for the help, and guilty for having been angry with them."],
      ["Someone keeps putting off a task out of fear, and the deadline passes.", "What feeling most likely comes next?", "Regret", ["Pride", "Joy", "Hope"], "The chance was lost because of their own choice to put it off. That is regret."],
      ["Someone is hopeful about a medical test, the result is bad, and later they learn the lab mixed up the results.", "What is the last feeling most likely to be?", "Relief", ["Despair", "Shame", "Jealousy"], "Hope, then bad news, then learning the bad news was a mistake: the last feeling is relief."],
      ["Someone feels lonely in a new city, then the neighbours start inviting them over every week.", "Over time, the loneliness most likely turns into…", "Belonging", ["Jealousy", "Guilt", "Panic"], "Being welcomed again and again by the people around them replaces loneliness with a sense of belonging."],
    ],
  ],
  es: [
    [
      ["", "Una molestia que va creciendo, sin poder descargarla, casi siempre se convierte en…", "Furia", ["Aburrimiento", "Orgullo", "Alivio"], "La molestia es un enojo leve. Si sigue creciendo y no tiene por dónde salir, se convierte en furia."],
      ["", "Una preocupación que no para de crecer suele convertirse en…", "Pánico", ["Alegría", "Orgullo", "Aburrimiento"], "La preocupación es una forma de miedo. El miedo en su punto más fuerte es pánico."],
      ["", "Cuando algo que temías al final no pasa, lo normal es sentir…", "Alivio", ["Culpa", "Celos", "Vergüenza"], "El alivio es lo que se siente cuando algo que temías no pasa."],
      ["", "Una satisfacción que se vuelve más fuerte puede convertirse en…", "Alegría", ["Enojo", "Miedo", "Culpa"], "La alegría es el mismo sentimiento agradable que la satisfacción, pero más fuerte."],
      ["", "Una tristeza que dura mucho y no se va puede convertirse en…", "Desesperanza", ["Orgullo", "Sorpresa", "Entusiasmo"], "Una tristeza que dura y no se va quita la esperanza, y eso se convierte en desesperanza."],
    ],
    [
      ["Alguien siente alivio cuando se resuelve un problema, y después se entera de que lo resolvió un amigo al que había culpado.", "¿Qué siente después, lo más probable?", "Culpa", ["Orgullo", "Celos", "Aburrimiento"], "Había culpado justo al amigo que resolvió el problema. Darte cuenta de que fuiste injusto con alguien da culpa."],
      ["Alguien está entusiasmado con una fiesta, y después se entera de que no va nadie más.", "¿Qué siente después, lo más probable?", "Desilusión", ["Alivio", "Orgullo", "Culpa"], "Algo que esperaba con ganas se cae, y eso da desilusión."],
      ["Alguien tiene miedo de desaprobar un examen, estudia mucho y aprueba con la nota más alta.", "¿Qué siente después, lo más probable?", "Orgullo", ["Vergüenza", "Celos", "Culpa"], "Se esforzó y le salió bien. El éxito después del esfuerzo da orgullo."],
      ["A alguien le gusta un regalo, y después descubre que quien se lo dio se olvidó de su cumpleaños y lo compró a último momento.", "¿Qué siente después, lo más probable?", "Desilusión", ["Orgullo", "Alivio", "Miedo"], "El regalo parecía pensado, pero fue una compra de último momento. Descubrir que le importabas menos de lo que creías da desilusión."],
      ["Alguien se sorprende porque tocan la puerta tarde a la noche, y después ve afuera a un desconocido que actúa raro.", "¿Qué siente después, lo más probable?", "Miedo", ["Alegría", "Orgullo", "Aburrimiento"], "La sorpresa se convierte en miedo cuando lo que sorprende parece un posible peligro."],
    ],
    [
      ["Alguien siente celos del éxito de un amigo, y después ve lo mucho que su amigo trabajó para lograrlo.", "¿Qué reemplaza a los celos, lo más probable?", "Admiración", ["Desprecio", "Miedo", "Asco"], "Ver el esfuerzo detrás del éxito muestra que se lo ganó, así que los celos dejan paso a la admiración."],
      ["Alguien está enojado con un compañero de trabajo por un error, y después descubre que el compañero lo estaba cubriendo.", "¿Qué reemplaza al enojo, lo más probable?", "Agradecimiento mezclado con culpa", ["Orgullo", "Desprecio", "Aburrimiento"], "El compañero lo estaba protegiendo: agradecido por la ayuda y culpable por haberse enojado con él."],
      ["Alguien posterga una tarea por miedo una y otra vez, y se pasa la fecha de entrega.", "¿Qué siente después, lo más probable?", "Arrepentimiento", ["Orgullo", "Alegría", "Esperanza"], "La oportunidad se perdió por su propia decisión de postergar. Eso es arrepentimiento."],
      ["Alguien espera con esperanza un estudio médico, el resultado es malo, y después se entera de que el laboratorio confundió los resultados.", "¿Cuál es el último sentimiento, lo más probable?", "Alivio", ["Desesperanza", "Vergüenza", "Celos"], "Esperanza, después una mala noticia, después saber que la mala noticia era un error: el último sentimiento es alivio."],
      ["Alguien se siente solo en una ciudad nueva, y después los vecinos empiezan a invitarlo todas las semanas.", "Con el tiempo, la soledad se convierte en…", "Pertenencia", ["Celos", "Culpa", "Pánico"], "Que la gente de alrededor lo reciba una y otra vez reemplaza la soledad por la sensación de pertenecer."],
    ],
  ],
};

export const HELP: { en: Tiers<Story4>; es: Tiers<Story4> } = {
  en: [
    [
      ["Your friend is very nervous about a job interview tomorrow.", "What will most likely help them?", "Practise likely questions with them", ["Tell them the job doesn't matter", "Change the subject", "Tell them how tough the interviewers are"], "Practising gives them a plan and confidence for what will really happen. Saying the job doesn't matter brushes off their feelings, and scary stories about the interviewers make the nerves worse."],
      ["A classmate is crying because their pet died.", "What would help most?", "Listen and let them talk about their pet", ["Tell them it was only an animal", "Tell a funny joke", "Ignore it so they aren't embarrassed"], "Grief needs to be heard, so listening helps them share it. Calling it \"only an animal\", joking or ignoring it all brush off the loss."],
      ["Your little brother is scared of the dark at bedtime.", "What would help most?", "Leave a small night light on", ["Tell him scary stories", "Laugh at him for being scared", "Turn off every light"], "A night light takes away what he is scared of without making fun of him. Scary stories, laughing or more darkness make it worse."],
      ["A new student sits alone at lunch on the first day.", "What would help most?", "Invite them to sit with you", ["Stare at them", "Wait until they ask", "Tell the others to leave them alone"], "An invitation solves the problem at once: they are no longer alone. Waiting leaves the hard first step to the person who already feels left out."],
      ["Your friend is upset after losing a game because the referee made a bad call.", "What would help most?", "Let them cool down and agree it was unfair", ["Tell them it was their fault", "Make them play again right away", "Laugh about it"], "Feelings run high right after a loss. Time to cool down, plus agreeing it was unfair, shows you are on their side. Blame, pushing them to play or laughing adds to the hurt."],
    ],
    [
      ["You feel your anger rising during an argument with a friend.", "What is the most helpful thing to do?", "Take a short break and calm down before answering", ["Shout so they understand", "Say the most hurtful thing you can", "Pretend to agree and stay angry"], "A short pause lets the anger drop so you can answer clearly. Shouting or saying something hurtful makes the fight bigger; pretending to agree only hides the anger."],
      ["You are anxious about giving a talk to your class.", "What will most likely help?", "Practise it out loud a few times beforehand", ["Skip the talk without telling anyone", "Stay up all night worrying", "Drink lots of coffee right before"], "Saying the talk out loud makes it familiar, and that lowers anxiety. Skipping it, worrying all night or lots of coffee make the anxiety worse."],
      ["Two friends in your group are arguing, and the others are taking sides.", "What would help most?", "Let each friend explain calmly while the others listen", ["Tell everyone to pick a side", "Post about it online", "Leave the group without a word"], "When each person is heard calmly, the conflict cools down. Taking sides, posting about it or walking out makes it bigger."],
      ["Your friend has just failed an exam and says, \"I'm so stupid.\"", "What would help most?", "Remind them one exam doesn't define them, and offer to study together", ["Agree that the exam was easy", "Tell them your own better grade", "Say nothing and change the subject"], "It answers the hurtful thought (\"I'm so stupid\") and offers real help. Saying the exam was easy or mentioning your better grade makes them feel worse."],
      ["You feel lonely after moving to a new city.", "What will most likely help?", "Join a club or class about something you enjoy", ["Stay inside until it passes", "Tell yourself nobody likes you", "Stop calling your old friends"], "A club or class puts you with people who like the same thing, which is how new friendships start. Staying in or dropping old friends deepens the loneliness."],
    ],
    [
      ["Your friend is grieving and keeps saying they don't want advice.", "What would help most?", "Stay with them and listen without trying to fix anything", ["Give them a list of things that will make them feel better", "Tell them everything happens for a reason", "Keep them busy so they don't think about it"], "They said they don't want advice, so respect that: being there and listening is the support. Lists of tips, \"everything happens for a reason\" and keeping them busy ignore what they asked for."],
      ["A coworker is stressed because they have too much work, but won't ask for help.", "What would help most?", "Offer to take one specific task off their hands", ["Tell them to relax", "Tell the boss they're struggling", "Say \"let me know if you need anything\""], "Someone who won't ask for help rarely takes up a vague offer; taking one clear task really lightens the load. \"Relax\" doesn't help, and telling the boss goes behind their back."],
      ["Your sister is nervous about a test and asks you to quiz her, but you're very tired.", "What is the best choice?", "Quiz her for a while and tell her when you need to stop", ["Refuse and tell her she'll be fine", "Quiz her for hours without a break", "Do her homework for her instead"], "It helps your sister and is honest about your limits. Refusing leaves her alone with the nerves, hours without a break wear you out, and doing her homework doesn't help her learn."],
      ["A friend tells you a worrying secret: they have stopped eating properly.", "What would help most?", "Tell them you care and encourage them to talk to a doctor or an adult they trust", ["Keep it secret no matter what", "Tell everyone at school", "Tell them to just eat more"], "Not eating properly can be a real health risk, so it is too serious to keep secret, but telling everyone would betray them. Caring, and getting a doctor or trusted adult involved, is both safe and kind."],
      ["Your teammate made the mistake that lost the match and is very upset.", "What would help most?", "Remind them of the good things they did, and that the team lost together", ["Tell them it wasn't a big deal at all", "Point out exactly what they did wrong, right away", "Avoid them so they aren't embarrassed"], "It eases the blame: they also did good things, and a team wins and loses together. Saying it was nothing ignores their feelings, and listing their mistakes right away piles on."],
    ],
  ],
  es: [
    [
      ["Tu amigo está muy nervioso por una entrevista de trabajo mañana.", "¿Qué lo va a ayudar más, lo más probable?", "Practicar con él las preguntas que le pueden hacer", ["Decirle que el trabajo no importa", "Cambiar de tema", "Contarle lo duros que son los entrevistadores"], "Practicar le da un plan y confianza para lo que va a pasar de verdad. Decirle que el trabajo no importa le resta importancia a lo que siente, y hablar de entrevistadores duros aumenta los nervios."],
      ["Un compañero llora porque se murió su mascota.", "¿Qué ayudaría más?", "Escucharlo y dejar que hable de su mascota", ["Decirle que era solo un animal", "Contar un chiste", "Ignorarlo para que no le dé vergüenza"], "El duelo necesita ser escuchado, así que escuchar lo ayuda a compartirlo. Decir que era \"solo un animal\", hacer chistes o ignorarlo le restan importancia a la pérdida."],
      ["Tu hermanito tiene miedo a la oscuridad a la hora de dormir.", "¿Qué ayudaría más?", "Dejarle prendida una lucecita", ["Contarle historias de terror", "Reírte de él por tener miedo", "Apagar todas las luces"], "Una lucecita le saca lo que le da miedo sin burlarse de él. Las historias de terror, reírse o más oscuridad lo empeoran."],
      ["Un alumno nuevo se sienta solo en el almuerzo el primer día.", "¿Qué ayudaría más?", "Invitarlo a sentarse con vos", ["Quedarte mirándolo", "Esperar a que te lo pida", "Decirles a los demás que lo dejen solo"], "Invitarlo resuelve el problema enseguida: deja de estar solo. Esperar deja el primer paso, el más difícil, a quien ya se siente afuera."],
      ["Tu amiga está mal después de perder un partido porque el árbitro cobró mal.", "¿Qué ayudaría más?", "Dejar que se calme y darle la razón en que fue injusto", ["Decirle que fue culpa suya", "Hacerla jugar otra vez enseguida", "Reírte del tema"], "Justo después de perder los ánimos están a flor de piel. Darle tiempo para calmarse y reconocer que fue injusto muestra que estás de su lado. Culparla, hacerla jugar o reírse duele más."],
    ],
    [
      ["Sentís que te está subiendo el enojo en una discusión con un amigo.", "¿Qué es lo más útil?", "Tomarte un momento para calmarte antes de contestar", ["Gritar para que entienda", "Decir lo más hiriente que se te ocurra", "Hacer como que estás de acuerdo y seguir enojado"], "Una pausa corta deja bajar el enojo para que puedas contestar con claridad. Gritar o decir algo hiriente agranda la pelea; hacer como que estás de acuerdo solo esconde el enojo."],
      ["Estás ansioso por dar una exposición en clase.", "¿Qué te va a ayudar más, lo más probable?", "Practicarla en voz alta varias veces antes", ["Faltar a la exposición sin avisar", "Quedarte toda la noche preocupado", "Tomar mucho café justo antes"], "Decirla en voz alta la vuelve conocida, y eso baja la ansiedad. Faltar, pasar la noche preocupado o tomar mucho café la aumentan."],
      ["Dos amigos de tu grupo se pelean y los demás toman partido.", "¿Qué ayudaría más?", "Que cada uno explique con calma mientras los demás escuchan", ["Decirles a todos que elijan un bando", "Publicarlo en las redes", "Irte del grupo sin decir nada"], "Cuando cada uno se siente escuchado con calma, el conflicto se enfría. Tomar partido, publicarlo o irse lo agranda."],
      ["Tu amiga desaprobó un examen y dice: \"Soy una tonta\".", "¿Qué ayudaría más?", "Recordarle que un examen no la define y ofrecerle estudiar juntas", ["Decirle que el examen era fácil", "Contarle que a vos te fue mejor", "No decir nada y cambiar de tema"], "Responde al pensamiento hiriente (\"soy una tonta\") y ofrece una ayuda concreta. Decirle que era fácil o contarle que a vos te fue mejor la hace sentir peor."],
      ["Te sentís solo después de mudarte a una ciudad nueva.", "¿Qué te va a ayudar más, lo más probable?", "Anotarte en un club o un curso de algo que te guste", ["Quedarte encerrado hasta que se pase", "Decirte que nadie te quiere", "Dejar de llamar a tus viejos amigos"], "Un club o un curso te junta con gente a la que le gusta lo mismo, y así empiezan las amistades nuevas. Encerrarte o dejar a tus viejos amigos profundiza la soledad."],
    ],
    [
      ["Tu amigo está de duelo y repite que no quiere consejos.", "¿Qué ayudaría más?", "Acompañarlo y escucharlo sin intentar arreglar nada", ["Darle una lista de cosas para sentirse mejor", "Decirle que todo pasa por algo", "Mantenerlo ocupado para que no piense"], "Dijo que no quiere consejos, así que hay que respetarlo: estar y escuchar es el apoyo. Las listas de consejos, el \"todo pasa por algo\" y mantenerlo ocupado ignoran lo que pidió."],
      ["Una compañera de trabajo está estresada porque tiene demasiado trabajo, pero no pide ayuda.", "¿Qué ayudaría más?", "Ofrecerte a hacer una tarea concreta en su lugar", ["Decirle que se relaje", "Contarle al jefe que no da abasto", "Decirle \"avisame si necesitás algo\""], "Quien no pide ayuda casi nunca acepta un ofrecimiento vago; hacerse cargo de una tarea concreta alivia de verdad. \"Relajate\" no sirve, y contarle al jefe es ir por detrás de ella."],
      ["Tu hermana está nerviosa por una prueba y te pide que le tomes preguntas, pero estás muy cansado.", "¿Qué es lo mejor?", "Tomarle preguntas un rato y avisarle cuando necesites parar", ["Negarte y decirle que le va a ir bien", "Tomarle preguntas horas sin parar", "Hacerle la tarea vos"], "Ayuda a tu hermana y es honesto con tus límites. Negarte la deja sola con los nervios, horas sin parar te agotan y hacerle la tarea no la ayuda a aprender."],
      ["Un amigo te cuenta un secreto que te preocupa: dejó de comer bien.", "¿Qué ayudaría más?", "Decirle que te importa y animarlo a hablar con un médico o un adulto de confianza", ["Guardar el secreto pase lo que pase", "Contárselo a todo el colegio", "Decirle que coma más y listo"], "Dejar de comer bien puede ser un riesgo real para la salud, así que es demasiado grave para guardarlo, pero contárselo a todos sería traicionarlo. Mostrarle que te importa y sumar a un médico o un adulto de confianza es seguro y amable."],
      ["Tu compañera de equipo cometió el error que les hizo perder el partido y está muy mal.", "¿Qué ayudaría más?", "Recordarle lo bueno que hizo y que perdieron todas juntas", ["Decirle que no fue nada", "Marcarle enseguida exactamente qué hizo mal", "Evitarla para que no se avergüence"], "Alivia la culpa: también hizo cosas buenas, y un equipo gana y pierde junto. Decirle que no fue nada ignora lo que siente, y marcarle los errores enseguida la hunde más."],
    ],
  ],
};

/** sarcasm: [situation, what is said, what they mean, wrong x3] */
export type Sarc = [string, string, string, string[]];
export const SARCASM: { en: Tiers<Sarc>; es: Tiers<Sarc> } = {
  en: [
    [
      ["A colleague walks into a meeting 40 minutes late. Someone says:", "Impeccable timing, as usual.", "They are criticising the lateness", ["They are praising the colleague", "The meeting started early", "They lost track of time"]],
      ["It starts pouring with rain just as Ana steps outside without an umbrella. She says:", "Great. Just perfect.", "She is annoyed about the rain", ["She loves the rain", "She thinks the weather is perfect", "She is glad she went out"]],
      ["Leo burns the toast so badly that the kitchen fills with smoke. His sister says:", "Wow, chef of the year.", "She is teasing him for burning it", ["She thinks he is a great cook", "She wants more toast", "She is giving him a prize"]],
      ["Mia's brother eats all the ice cream and puts the empty box back in the freezer. Mia says:", "Thanks so much for saving me some.", "She is annoyed that he ate it all", ["She is really thanking him", "She didn't want any", "She thinks there is some left"]],
      ["The bus breaks down for the third time this week. A passenger says:", "This bus company really is the best.", "The bus company is unreliable", ["The bus company is excellent", "The passenger works there", "The bus is brand new"]],
    ],
    [
      ["Guests are still chatting at 1 a.m. The host yawns and says:", "Well, it's getting quite late…", "The host would like the guests to go home", ["The host is telling them the time", "The host wants them to stay longer", "The host is surprised"]],
      ["In a cold office, a visitor sitting by the open window says:", "It's a bit chilly in here, isn't it?", "They would like the window closed", ["They like the cold", "They are asking about the weather forecast", "They want a cold drink"]],
      ["After a huge storm floods the whole street, a neighbour looks out and says:", "Bit of a wet day.", "They are joking by making a disaster sound small", ["They think it barely rained", "They didn't see the flood", "They are worried about a drought"]],
      ["Your friend tastes your soup, puts the spoon down slowly and says:", "It's… interesting.", "They don't really like it", ["They find it fascinating", "They want the recipe", "They want a second bowl"]],
      ["A student hands in homework that is one line long. The teacher says:", "Well, you certainly didn't overdo it.", "The student did far too little", ["The student worked too hard", "The homework is excellent", "The teacher wants less work"]],
    ],
    [
      ["Pedro has complained about his job every day for a year. When he finally quits, his friend says:", "Oh no, I'll miss hearing about that place.", "The friend is glad the complaining will stop", ["The friend will really miss the stories", "The friend wants Pedro to go back", "The friend works there too"]],
      ["Lara spends three hours building a shelf. When she finishes, six screws are left over. She says:", "Clearly the instructions were optional.", "She is joking that she may have built it wrong", ["She thinks instructions are useless", "She is proud of saving screws", "She wants to build another one"]],
      ["A man who boasts that he never gets lost has driven the family in circles for an hour. His daughter says:", "Good thing we have an expert navigator.", "She is mocking his claim that he never gets lost", ["She trusts his sense of direction", "She wants him to keep driving", "She is thanking him for the trip"]],
      ["During a heatwave the power goes out and the air conditioning stops. Someone says:", "And here I was, worried we'd get cold.", "They are joking about how hot it is going to get", ["They are worried about the cold", "They like the heat", "They want a jacket"]],
      ["Julia's flatmate leaves dirty dishes in the sink every day. One day he washes a single cup. Julia says:", "Careful, don't wear yourself out.", "She thinks one cup is far too little", ["She is worried he is tired", "She wants him to stop washing up", "She thinks he washes too much"]],
    ],
  ],
  es: [
    [
      ["Un compañero llega a una reunión 40 minutos tarde. Alguien dice:", "Puntualísimo, como siempre.", "Está criticando que llegó tarde", ["Está elogiando al compañero", "La reunión empezó antes", "Perdió la noción del tiempo"]],
      ["Se larga a llover fuerte justo cuando Ana sale sin paraguas. Ella dice:", "Genial. Justo lo que necesitaba.", "Está fastidiada por la lluvia", ["Le encanta la lluvia", "Necesitaba mojarse", "Está contenta de haber salido"]],
      ["Leo quema tanto las tostadas que la cocina se llena de humo. Su hermana dice:", "Uy, el chef del año.", "Lo está cargando por quemarlas", ["Cree que cocina muy bien", "Quiere más tostadas", "Le está dando un premio"]],
      ["El hermano de Mía se come todo el helado y vuelve a guardar el pote vacío en el freezer. Mía dice:", "Gracias por dejarme un poquito, eh.", "Está enojada porque se lo comió todo", ["Le está agradeciendo de verdad", "Ella no quería helado", "Cree que quedó un poco"]],
      ["El colectivo se rompe por tercera vez en la semana. Un pasajero dice:", "Qué empresa de colectivos tan confiable.", "La empresa no es nada confiable", ["La empresa es excelente", "El pasajero trabaja ahí", "El colectivo es nuevo"]],
    ],
    [
      ["A la una de la mañana los invitados siguen charlando. El dueño de casa bosteza y dice:", "Bueno, ya se está haciendo tarde…", "Quiere que los invitados se vayan", ["Les está diciendo la hora", "Quiere que se queden más", "Está sorprendido"]],
      ["En una oficina fría, una visita sentada al lado de la ventana abierta dice:", "Está medio fresco acá, ¿no?", "Quiere que cierren la ventana", ["Le gusta el frío", "Pregunta por el pronóstico", "Quiere algo frío para tomar"]],
      ["Después de una tormenta enorme que inundó toda la cuadra, un vecino mira afuera y dice:", "Lloviznó un poquito, ¿no?", "Está bromeando al hacer chiquito un desastre", ["Cree que casi no llovió", "No vio la inundación", "Le preocupa la sequía"]],
      ["Tu amigo prueba tu sopa, deja la cuchara despacio y dice:", "Es… interesante.", "No le gusta mucho", ["Le parece fascinante", "Quiere la receta", "Quiere repetir"]],
      ["Un alumno entrega una tarea de una sola línea. La profesora dice:", "Bueno, se ve que no te mataste.", "El alumno hizo demasiado poco", ["El alumno trabajó de más", "La tarea es excelente", "La profesora quiere menos trabajo"]],
    ],
    [
      ["Pedro se quejó de su trabajo todos los días durante un año. Cuando por fin renuncia, su amigo le dice:", "Ay, voy a extrañar tus historias de ese lugar.", "El amigo se alegra de que se terminen las quejas", ["El amigo va a extrañar de verdad las historias", "El amigo quiere que Pedro vuelva", "El amigo también trabaja ahí"]],
      ["Lara tarda tres horas en armar un estante. Cuando termina, le sobran seis tornillos. Dice:", "Evidentemente, las instrucciones eran opcionales.", "Está bromeando con que quizá lo armó mal", ["Cree que las instrucciones no sirven", "Está orgullosa de ahorrar tornillos", "Quiere armar otro"]],
      ["Un señor que se jacta de no perderse nunca hace una hora que da vueltas en el auto con la familia. Su hija dice:", "Menos mal que tenemos un experto en orientación.", "Se está burlando de que dice que nunca se pierde", ["Confía en su sentido de la orientación", "Quiere que siga manejando", "Le agradece el paseo"]],
      ["En plena ola de calor se corta la luz y se apaga el aire acondicionado. Alguien dice:", "Y yo que tenía miedo de pasar frío.", "Está bromeando sobre el calor que va a hacer", ["Le preocupa el frío", "Le gusta el calor", "Quiere un abrigo"]],
      ["El compañero de departamento de Julia deja los platos sucios todos los días. Un día lava una sola taza. Julia dice:", "Cuidado, no te vayas a cansar.", "Le parece que una taza es muy poco", ["Le preocupa que esté cansado", "Quiere que deje de lavar", "Cree que lava demasiado"]],
    ],
  ],
};

/** fauxpas: [story, what is said, who says it, the other person, who said something awkward or
 *  hurtful without meaning to: 0 the speaker, 1 the other person (in the story), 2 nobody] */
export type FauxPas = [string, string, string, string, 0 | 1 | 2];
export const FAUXPAS: { en: Tiers<FauxPas>; es: Tiers<FauxPas> } = {
  en: [
    [
      ["Lucy painted her kitchen yellow herself. Her friend Ines doesn't know that. Ines visits and says:", "Whoever picked this yellow should be banned from paint shops!", "Ines", "Lucy", 0],
      ["Mark gives his Aunt Rosa a scarf he knitted himself. She opens it and says:", "It's lovely, thank you, Mark!", "Aunt Rosa", "Mark", 2],
      ["At dinner, Raúl doesn't know that his new friend Clara grew up in the north. He says to her:", "I can't stand people from the north, they're so rude.", "Raúl", "Clara", 0],
      ["Mia's grandpa gives her a book for her birthday. She already has a copy, but she says:", "Thank you, Grandpa, I love this author!", "Mia", "Grandpa", 2],
      ["Jake's dog died last week. His neighbour Ana hasn't heard. She meets Jake in the street and says:", "Where's that lovely dog of yours today?", "Ana", "Jake", 0],
    ],
    [
      ["Tom tells his colleague Nina that he's leaving the company, and asks her to keep it secret. At the team lunch, Nina forgets it's a secret and says:", "We'll miss you so much when you're gone, Tom!", "Nina", "Tom", 0],
      ["At Lucía's wedding, her cousin Tom, who hasn't met the groom, points at him and tells Lucía: \"Who invited that guy? He looks so bored.\" Lucía answers:", "That's my husband, Tom.", "Lucía", "Tom", 1],
      ["Olga baked a cake for the office. Her colleague Paul tastes it and says:", "This is delicious. Did you make it, Olga?", "Paul", "Olga", 2],
      ["Kim tells her friend Leo that she failed her driving test again. Leo says:", "Lots of people need a few tries. You'll get it.", "Leo", "Kim", 2],
      ["Sara has just bought an expensive new coat and is wearing it. Her friend Eva, who doesn't know it's new, says:", "That coat again? You should treat yourself to a new one.", "Eva", "Sara", 0],
    ],
    [
      ["Sofía is a vegetarian. Her friend Dani knows this and has cooked her a vegetable lasagne. At dinner, Dani tells the other guests:", "I made a meat one too, for anyone who wants it.", "Dani", "Sofía", 2],
      ["Marco lost his job last month and hasn't told anyone. At a barbecue, his friend Inés, who doesn't know, says loudly:", "People who lose their jobs just aren't trying hard enough.", "Inés", "Marco", 0],
      ["Rita told her friends this morning that she is getting divorced. Paula arrived late and didn't hear. She says to Rita:", "You and Jorge are the perfect couple. What's your secret?", "Paula", "Rita", 0],
      ["In a job interview, Ms Díaz mentions that she wrote the company handbook. Later the candidate, Iván, says:", "I read your handbook before coming. It was very clear.", "Iván", "Ms Díaz", 2],
      ["At a family lunch, Uncle Félix says to his niece Ema, who is a nurse: \"Nurses just do what the doctors tell them.\" Ema, who is the head nurse at her hospital, answers:", "Come and spend a day with us some time, Uncle.", "Ema", "Uncle Félix", 1],
    ],
  ],
  es: [
    [
      ["Lucía pintó ella misma su cocina de amarillo. Su amiga Inés no lo sabe. Inés la visita y dice:", "¡Al que eligió este amarillo habría que prohibirle entrar a una pinturería!", "Inés", "Lucía", 0],
      ["Marcos le regala a su tía Rosa una bufanda que tejió él mismo. Ella la abre y dice:", "¡Qué linda, gracias, Marcos!", "la tía Rosa", "Marcos", 2],
      ["En una cena, Raúl no sabe que su nueva amiga Clara se crió en el norte. Le dice:", "No soporto a la gente del norte, son muy maleducados.", "Raúl", "Clara", 0],
      ["El abuelo de Mía le regala un libro para su cumpleaños. Ella ya lo tiene, pero le dice:", "¡Gracias, abuelo, me encanta este autor!", "Mía", "el abuelo", 2],
      ["El perro de Jacinto murió la semana pasada. Su vecina Ana no se enteró. Se cruza con Jacinto en la calle y le dice:", "¿Y tu perro tan lindo? ¿Hoy no salió?", "Ana", "Jacinto", 0],
    ],
    [
      ["Tomás le cuenta a su compañera Nina que se va de la empresa y le pide que no se lo cuente a nadie. En el almuerzo del equipo, Nina se olvida de que era un secreto y dice:", "¡Te vamos a extrañar mucho cuando te vayas, Tomás!", "Nina", "Tomás", 0],
      ["En el casamiento de Lucía, su primo Tomás, que no conoce al novio, lo señala y le dice a Lucía: \"¿Quién invitó a ese? Tiene una cara de aburrido…\". Lucía contesta:", "Es mi marido, Tomás.", "Lucía", "Tomás", 1],
      ["Olga hizo una torta para la oficina. Su compañero Pablo la prueba y dice:", "Está buenísima. ¿La hiciste vos, Olga?", "Pablo", "Olga", 2],
      ["Kim le cuenta a su amigo Leo que volvió a desaprobar el examen de manejo. Leo le dice:", "Un montón de gente necesita varios intentos. Ya vas a aprobar.", "Leo", "Kim", 2],
      ["Sara se compró un tapado nuevo y carísimo, y lo tiene puesto. Su amiga Eva, que no sabe que es nuevo, le dice:", "¿Otra vez ese tapado? Date un gusto y comprate uno nuevo.", "Eva", "Sara", 0],
    ],
    [
      ["Sofía es vegetariana. Su amigo Dani lo sabe y le cocinó una lasaña de verduras. En la cena, Dani les dice a los demás invitados:", "También hice una de carne, para el que quiera.", "Dani", "Sofía", 2],
      ["Marco se quedó sin trabajo el mes pasado y no se lo contó a nadie. En un asado, su amiga Inés, que no sabe nada, dice en voz alta:", "El que se queda sin trabajo es porque no se esfuerza lo suficiente.", "Inés", "Marco", 0],
      ["Hoy a la mañana Rita les contó a sus amigas que se está divorciando. Paula llegó tarde y no lo escuchó. Le dice a Rita:", "Vos y Jorge son la pareja perfecta. ¿Cuál es el secreto?", "Paula", "Rita", 0],
      ["En una entrevista de trabajo, la señora Díaz comenta que ella escribió el manual de la empresa. Después el candidato, Iván, dice:", "Leí su manual antes de venir. Es muy claro.", "Iván", "la señora Díaz", 2],
      ["En un almuerzo familiar, el tío Félix le dice a su sobrina Ema, que es enfermera: \"Las enfermeras hacen lo que les dicen los médicos y listo\". Ema, que es la jefa de enfermería de su hospital, contesta:", "Vení a pasar un día con nosotras alguna vez, tío.", "Ema", "el tío Félix", 1],
    ],
  ],
};

/* ---------------- tom: the story text ---------------- */
export interface TomText {
  names: string[];
  /** [the thing, its pronoun ("it" / "la"), "is" / "are"] */
  things: [string, string, string][];
  /** where it can be, as said after "puts the keys" ("in the drawer") */
  places: string[];
  intro: string; put: string; move: string; leave: string; back: string; peek: string;
  ask: { look: string; real: string; think: string };
  and: (xs: string[]) => string;
  cap: (s: string) => string;
}
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
export const TOM_TXT: Record<Lang, TomText> = {
  en: {
    names: ["Mia", "Leo", "Ana", "Sam", "Nora", "Ben", "Lucy", "Tom"],
    things: [["the keys", "them", "are"], ["the ball", "it", "is"], ["the chocolate", "it", "is"], ["the book", "it", "is"], ["the coin", "it", "is"], ["the phone", "it", "is"]],
    places: ["in the drawer", "in the red box", "in the blue box", "in the basket", "in the bag", "under the bed", "in the cupboard"],
    intro: "{all} are at home.",
    put: "{p} puts {o} {l}.",
    move: "{p} takes {o} out and puts {pr} {l}.",
    leave: "{p} goes out.",
    back: "{p} comes back in.",
    peek: "From outside, {p} looks in through the window and sees where {o} {be}. Nobody notices.",
    ask: { look: "Where will {p} look for {o} first?", real: "Where {be} {o} now?", think: "Where does {p} think {q} will look for {o} first?" },
    and: (xs) => (xs.length === 2 ? `${xs[0]} and ${xs[1]}` : `${xs.slice(0, -1).join(", ")} and ${xs[xs.length - 1]}`),
    cap,
  },
  es: {
    names: ["Lucía", "Mateo", "Ana", "Nico", "Sofi", "Tomás", "Vera", "Juan"],
    things: [["las llaves", "las", "están"], ["la pelota", "la", "está"], ["el chocolate", "lo", "está"], ["el libro", "lo", "está"], ["la moneda", "la", "está"], ["el celular", "lo", "está"]],
    places: ["en el cajón", "en la caja roja", "en la caja azul", "en la canasta", "en la mochila", "debajo de la cama", "en el placard"],
    intro: "{all} están en casa.",
    put: "{p} pone {o} {l}.",
    move: "{p} saca {o} y {pr} pone {l}.",
    leave: "{p} sale.",
    back: "{p} vuelve a entrar.",
    peek: "Desde afuera, {p} mira por la ventana y ve dónde {be} {o}. Nadie se da cuenta.",
    ask: { look: "¿Dónde va a buscar {p} {o} primero?", real: "¿Dónde {be} {o} ahora?", think: "¿Dónde cree {p} que {q} va a buscar {o} primero?" },
    and: (xs) => (xs.length === 2 ? `${xs[0]} y ${xs[1]}` : `${xs.slice(0, -1).join(", ")} y ${xs[xs.length - 1]}`),
    cap,
  },
};
