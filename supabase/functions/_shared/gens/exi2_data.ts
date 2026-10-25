// Hand-written banks for the second EXI set (gens/exi2.ts), 2026-10-25. NOT from the
// prototype. Logic, not beliefs: every answer follows from the words alone. Three tiers
// (d 1-3, 4-7, 8-10); EN and ES (rioplatense).

import type { Tiers } from "./lin2_data.ts";

/** What's assumed: [argument, the gap it relies on, wrong x3 (true-ish or beside the point)] */
export type Assume = [string, string, string[]];
export const ASSUME: { en: Tiers<Assume>; es: Tiers<Assume> } = {
  en: [
    [
      ["Lena has the most followers, so her advice must be the best.", "Being popular means being right.", ["Lena gives advice.", "Her followers read her posts.", "Advice can be good or bad."]],
      ["This phone is the most expensive, so it must be the best.", "A higher price means better quality.", ["Phones can be expensive.", "The phone is new.", "People like good phones."]],
      ["It rained every day last week, so it will rain tomorrow.", "The weather will keep doing what it did last week.", ["Rain is annoying.", "Last week was long.", "Tomorrow is a weekday."]],
      ["Max didn't answer my message, so he must be angry with me.", "Not answering can only mean being angry.", ["Max has a phone.", "Messages are important.", "Max is often busy."]],
      ["That restaurant is always full, so the food must be good.", "A busy restaurant means good food.", ["The restaurant is big.", "People eat dinner.", "Good food costs more."]],
    ],
    [
      ["Students who use phones in class get lower grades, so banning phones will raise grades.", "The phones cause the lower grades, not something else.", ["Students own phones.", "Grades matter.", "Schools can make rules."]],
      ["Traffic in our town is terrible, so we need a new road.", "A new road would reduce the traffic.", ["The town already has roads.", "Traffic is annoying.", "Roads are expensive."]],
      ["Ana got the job because she went to the best university.", "Her university is the reason she was chosen.", ["Ana applied for the job.", "The job was hard to get.", "Universities teach many subjects."]],
      ["The new medicine works: everyone who took it got better.", "They wouldn't have got better without it.", ["The medicine is new.", "The people were ill.", "Medicines can help."]],
      ["Leo is a great pianist, so he'll be a great piano teacher.", "Being good at something means you can teach it well.", ["Leo plays the piano.", "Teachers need students.", "Pianos are expensive."]],
    ],
    [
      ["Crime went down after the city put up street lights, so the lights reduced crime.", "Nothing else that changed at the same time explains the drop.", ["Street lights cost money.", "Crime is a problem.", "The city has many streets."]],
      ["Most people in our survey liked the new logo, so most of our customers will like it.", "The people surveyed are like our customers.", ["Logos matter to companies.", "The survey took a long time.", "Customers buy products."]],
      ["If we lower our prices we'll sell more, so we'll make more money.", "Selling more will make up for the lower price.", ["Prices can change.", "The shop wants money.", "The products are good."]],
      ["Adults find this puzzle hard, so children will find it even harder.", "Children do worse than adults at this kind of puzzle.", ["The puzzle exists.", "Adults like puzzles.", "Hard puzzles are unfair."]],
      ["Nobody has complained about the new rule, so everyone must be happy with it.", "Unhappy people would have complained.", ["The rule is new.", "Rules can change.", "Complaints take time."]],
    ],
  ],
  es: [
    [
      ["Lena tiene más seguidores que nadie, así que sus consejos tienen que ser los mejores.", "Ser popular significa tener razón.", ["Lena da consejos.", "Sus seguidores leen lo que publica.", "Los consejos pueden ser buenos o malos."]],
      ["Este celular es el más caro, así que tiene que ser el mejor.", "Un precio más alto significa mejor calidad.", ["Los celulares pueden ser caros.", "El celular es nuevo.", "A la gente le gustan los buenos celulares."]],
      ["Llovió todos los días la semana pasada, así que mañana va a llover.", "El tiempo va a seguir igual que la semana pasada.", ["La lluvia molesta.", "La semana pasada fue larga.", "Mañana es día de semana."]],
      ["Max no me contestó el mensaje, así que debe estar enojado conmigo.", "No contestar solo puede significar estar enojado.", ["Max tiene celular.", "Los mensajes son importantes.", "Max suele estar ocupado."]],
      ["Ese restaurante siempre está lleno, así que la comida tiene que ser buena.", "Un restaurante lleno significa buena comida.", ["El restaurante es grande.", "La gente sale a cenar.", "La buena comida cuesta más."]],
    ],
    [
      ["Los alumnos que usan el celular en clase sacan peores notas, así que prohibirlo va a mejorar las notas.", "El celular causa las malas notas, y no otra cosa.", ["Los alumnos tienen celular.", "Las notas importan.", "Las escuelas pueden poner reglas."]],
      ["El tránsito en el pueblo es terrible, así que hace falta una ruta nueva.", "Una ruta nueva reduciría el tránsito.", ["El pueblo ya tiene rutas.", "El tránsito molesta.", "Las rutas son caras."]],
      ["Ana consiguió el trabajo porque fue a la mejor universidad.", "La universidad es la razón por la que la eligieron.", ["Ana se postuló al trabajo.", "El trabajo era difícil de conseguir.", "Las universidades enseñan muchas materias."]],
      ["El remedio nuevo funciona: todos los que lo tomaron se curaron.", "No se habrían curado sin el remedio.", ["El remedio es nuevo.", "Las personas estaban enfermas.", "Los remedios pueden ayudar."]],
      ["Leo es un gran pianista, así que va a ser un gran profesor de piano.", "Ser bueno en algo significa saber enseñarlo bien.", ["Leo toca el piano.", "Los profesores necesitan alumnos.", "Los pianos son caros."]],
    ],
    [
      ["Los robos bajaron después de que la ciudad puso faroles, así que los faroles redujeron los robos.", "Ninguna otra cosa que cambió en ese momento explica la baja.", ["Los faroles cuestan plata.", "Los robos son un problema.", "La ciudad tiene muchas calles."]],
      ["A la mayoría de los encuestados les gustó el logo nuevo, así que a la mayoría de los clientes les va a gustar.", "Los encuestados se parecen a nuestros clientes.", ["Los logos importan a las empresas.", "La encuesta llevó mucho tiempo.", "Los clientes compran productos."]],
      ["Si bajamos los precios vamos a vender más, así que vamos a ganar más plata.", "Vender más va a compensar el precio más bajo.", ["Los precios pueden cambiar.", "El negocio quiere ganar plata.", "Los productos son buenos."]],
      ["A los adultos este acertijo les cuesta, así que a los chicos les va a costar todavía más.", "A los chicos les va peor que a los adultos con este tipo de acertijo.", ["El acertijo existe.", "A los adultos les gustan los acertijos.", "Los acertijos difíciles son injustos."]],
      ["Nadie se quejó de la regla nueva, así que todos deben estar contentos con ella.", "Los que no están contentos se habrían quejado.", ["La regla es nueva.", "Las reglas pueden cambiar.", "Las quejas llevan tiempo."]],
    ],
  ],
};

/** Says and unsays: [the self-defeating statement, three that are consistent] */
export type Contra = [string, string[]];
export const CONTRA: { en: Tiers<Contra>; es: Tiers<Contra> } = {
  en: [
    [
      ["Buy this pen and get a free gift for only $10 more.", ["Buy this pen and get a gift worth $10.", "Gifts are sometimes worth more than the pen.", "This pen costs $10."]],
      ["We have a strict open-door policy: the door is always locked.", ["Our door is locked at night.", "We prefer to keep the door open.", "Strict rules can be useful."]],
      ["I never say never.", ["I rarely say never.", "Never is a strong word.", "Some people often say never."]],
      ["Nobody goes to that café any more: it's always too crowded.", ["That café is crowded at lunchtime.", "Fewer people go to that café now.", "Crowded cafés can be noisy."]],
      ["The only rule here is that there are no rules.", ["There are very few rules here.", "The main rule here is to be kind.", "Some places have no written rules."]],
    ],
    [
      ["I know for certain that nobody can know anything for certain.", ["Some things are hard to know.", "I might be wrong about this.", "Most rules have exceptions."]],
      ["There is no such thing as truth, and that's the truth.", ["The truth can be hard to find.", "People disagree about what is true.", "Some statements are false."]],
      ["Never trust anyone, and trust me on that.", ["It takes time to trust someone.", "Some people are hard to trust.", "Trust can be lost quickly."]],
      ["Please ignore this sign.", ["Please read this sign.", "Some signs are ignored.", "This sign is new."]],
      ["Always avoid absolutes.", ["Absolutes are often wrong.", "Try to avoid exaggerating.", "Some words are stronger than others."]],
    ],
    [
      ["All generalisations are false.", ["Many generalisations are false.", "Some generalisations are useful.", "Generalisations can be unfair."]],
      ["Every rule has an exception, without exception.", ["Most rules have an exception.", "This rule has one exception.", "Some rules have no exceptions."]],
      ["Words can't describe anything.", ["Some feelings are hard to describe.", "Words can describe many things.", "Pictures can describe things too."]],
      ["You should never follow anyone's advice.", ["You should think about advice before following it.", "Some advice is bad.", "Advice from friends can help."]],
      ["Everything I say is wrong, including this.", ["Some things I say are wrong.", "I am often wrong.", "Everyone is wrong sometimes."]],
    ],
  ],
  es: [
    [
      ["Comprá esta birome y llevate un regalo gratis por solo $10 más.", ["Comprá esta birome y llevate un regalo que vale $10.", "A veces el regalo vale más que la birome.", "Esta birome cuesta $10."]],
      ["Tenemos una política estricta de puertas abiertas: la puerta está siempre cerrada con llave.", ["La puerta se cierra con llave de noche.", "Preferimos tener la puerta abierta.", "Las reglas estrictas pueden servir."]],
      ["Yo nunca digo nunca.", ["Casi nunca digo nunca.", "Nunca es una palabra fuerte.", "Hay gente que dice nunca muy seguido."]],
      ["Nadie va más a ese café: está siempre lleno.", ["Ese café se llena al mediodía.", "Ahora va menos gente a ese café.", "Los cafés llenos pueden ser ruidosos."]],
      ["La única regla acá es que no hay reglas.", ["Acá hay muy pocas reglas.", "La regla principal acá es ser amable.", "Algunos lugares no tienen reglas escritas."]],
    ],
    [
      ["Sé con total certeza que nadie puede saber nada con certeza.", ["Algunas cosas son difíciles de saber.", "Puedo estar equivocado en esto.", "Casi todas las reglas tienen excepciones."]],
      ["La verdad no existe, y esa es la verdad.", ["La verdad puede ser difícil de encontrar.", "La gente no se pone de acuerdo sobre qué es verdad.", "Algunas afirmaciones son falsas."]],
      ["No confíes en nadie, y creeme que es así.", ["Lleva tiempo confiar en alguien.", "En algunas personas cuesta confiar.", "La confianza se pierde rápido."]],
      ["Por favor, ignorá este cartel.", ["Por favor, leé este cartel.", "Algunos carteles se ignoran.", "Este cartel es nuevo."]],
      ["Evitá siempre los absolutos.", ["Los absolutos suelen estar equivocados.", "Tratá de no exagerar.", "Algunas palabras son más fuertes que otras."]],
    ],
    [
      ["Todas las generalizaciones son falsas.", ["Muchas generalizaciones son falsas.", "Algunas generalizaciones son útiles.", "Las generalizaciones pueden ser injustas."]],
      ["Toda regla tiene una excepción, sin excepción.", ["Casi todas las reglas tienen una excepción.", "Esta regla tiene una excepción.", "Algunas reglas no tienen excepciones."]],
      ["Las palabras no pueden describir nada.", ["Algunos sentimientos son difíciles de describir.", "Las palabras pueden describir muchas cosas.", "Las imágenes también pueden describir cosas."]],
      ["Nunca sigas el consejo de nadie.", ["Pensá un consejo antes de seguirlo.", "Algunos consejos son malos.", "Los consejos de amigos pueden ayudar."]],
      ["Todo lo que digo está mal, incluido esto.", ["Algunas cosas que digo están mal.", "Me equivoco seguido.", "Todos nos equivocamos a veces."]],
    ],
  ],
};

/** Wason, people version (d 1-3): [rule, what each card is, P-true, P-false, Q-true, Q-false] */
export type Deontic = [string, string, string, string, string, string];
export const DEONTIC: { en: Deontic[]; es: Deontic[] } = {
  en: [
    ["If someone is riding a bike, they must wear a helmet.", "Each card is a person: one side says what they're doing, the other what they're wearing.", "Riding a bike", "Walking", "Helmet", "No helmet"],
    ["If someone swims in the pool, they must wear a swim cap.", "Each card is a person: one side says what they're doing, the other what's on their head.", "Swimming", "Sunbathing", "Swim cap", "No cap"],
    ["If a parcel is sent express, it must have a red sticker.", "Each card is a parcel: one side says how it's sent, the other what sticker it has.", "Express", "Standard", "Red sticker", "No sticker"],
  ],
  es: [
    ["Si alguien anda en bici, tiene que usar casco.", "Cada carta es una persona: de un lado dice qué está haciendo y del otro qué tiene puesto.", "Anda en bici", "Camina", "Con casco", "Sin casco"],
    ["Si alguien nada en la pileta, tiene que usar gorra de natación.", "Cada carta es una persona: de un lado dice qué hace y del otro qué tiene en la cabeza.", "Nada", "Toma sol", "Con gorra", "Sin gorra"],
    ["Si un paquete va urgente, tiene que tener una etiqueta roja.", "Cada carta es un paquete: de un lado dice cómo se envía y del otro qué etiqueta tiene.", "Urgente", "Común", "Etiqueta roja", "Sin etiqueta"],
  ],
};

/** Needed or enough: things you can do and what you have. [act, cond] */
export const NECSUF_DOMAINS: { en: [string, string][]; es: [string, string][] } = {
  en: [["get into the concert", "a ticket"], ["swim in the pool", "a wristband"], ["borrow books", "a library card"], ["park here", "a permit"], ["open the safe", "the code"]],
  es: [["entrar al recital", "una entrada"], ["nadar en la pileta", "una pulsera"], ["sacar libros", "un carné de la biblioteca"], ["estacionar acá", "un permiso"], ["abrir la caja fuerte", "el código"]],
};
