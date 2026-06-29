use http-nu/router *
use http-nu/http *

# JSON-svar med en HTTP-statuskode (til fejl)
def jerr [status: int, msg: string] {
  {error: $msg} | to json
  | metadata set { merge {'http.response': {status: $status, headers: {"Content-Type": "application/json"}}} }
}
# JSON-svar (200) — pipe en value ind
def jok []: any -> any {
  to json | metadata set --content-type "application/json"
}

# AI IQ — en lille quiz der tester folks AI-viden.
# Spørgsmålene lever her i backenden og serveres som JSON til frontend'en.
const QUESTIONS = [
  {
    q: "Hvad står 'GPT' egentlig for?"
    options: [
      "Generative Pre-trained Transformer"
      "General Purpose Translator"
      "Giant Pile of Tensors"
      "Glorificeret Påstands-Tilfældiggenerator"
    ]
    answer: 0
    right: "Korrekt! Selvom 'Giant Pile of Tensors' teknisk set også passer ret godt."
    wrong: "Næ. Det er Generative Pre-trained Transformer — ikke noget med Optimus Prime."
  }
  {
    q: "Hvad kaldes det, når en sprogmodel selvsikkert finder på rent vrøvl?"
    options: [
      "Hallucination"
      "Kreativ regnskabsføring"
      "Improvisation"
      "En helt almindelig tirsdag"
    ]
    answer: 0
    right: "Ja! En hallucination. Modellen lyver ikke — den er bare meget, meget overbevist."
    wrong: "Det hedder en hallucination. (Selvom 'kreativ regnskabsføring' ramte tæt på.)"
  }
  {
    q: "Hvilket firma står bag Claude?"
    options: [
      "Anthropic"
      "OpenAI"
      "Google DeepMind"
      "Skynet Industries A/S"
    ]
    answer: 0
    right: "Præcis — Anthropic. Og nej, vi planlægger ikke at overtage verden. Endnu."
    wrong: "Det er Anthropic. Skynet er heldigvis stadig fiktion."
  }
  {
    q: "Hvad er en 'token' i en sprogmodel?"
    options: [
      "En stump tekst (ord eller orddel) som modellen behandler"
      "En kryptovaluta du kan tabe penge på"
      "En adgangsnøgle til API'et"
      "Et klippekort til bussen"
    ]
    answer: 0
    right: "Spot on. Modeller tænker i tokens, ikke i hele ord."
    wrong: "En token er en stump tekst. Du betaler ganske vist pr. token — men det er ikke krypto."
  }
  {
    q: "Hvad styrer 'temperature' når en model genererer tekst?"
    options: [
      "Hvor tilfældigt og kreativt outputtet bliver"
      "Hvor varm GPU'en bliver"
      "Modellens generelle humør"
      "Antal watt serveren bruger"
    ]
    answer: 0
    right: "Nemlig! Høj temperature = vildere svar. Lav = kedeligt men forudsigeligt."
    wrong: "Temperature styrer kreativiteten/tilfældigheden — ikke GPU'ens kernetemperatur."
  }
  {
    q: "Hvad er en 'transformer' i AI-sammenhæng?"
    options: [
      "En neural netværksarkitektur baseret på 'attention'"
      "En robot der kan forvandle sig til en lastbil"
      "En komponent i strømforsyningen"
      "Optimus Primes LinkedIn-profil"
    ]
    answer: 0
    right: "Korrekt — 'Attention Is All You Need'. Bogstaveligt talt papirets titel."
    wrong: "Det er en netværksarkitektur (attention). Beklager, ingen Autobots her."
  }
  {
    q: "Hvad gør RAG (Retrieval-Augmented Generation)?"
    options: [
      "Henter relevante dokumenter og giver dem til modellen som kontekst"
      "Får modellen til at svare på rim"
      "Renser træningsdata for bandeord"
      "Det er bare en fancy klud"
    ]
    answer: 0
    right: "Ja! RAG giver modellen 'eksterne noter', så den hallucinerer mindre."
    wrong: "RAG henter dokumenter og fodrer dem til modellen. Ikke en klud, desværre."
  }
  {
    q: "Hvad betyder 'overfitting'?"
    options: [
      "Modellen lærer træningsdata udenad og fejler på nyt data"
      "Modellen er for stor til din GPU"
      "Der er for mange lag i netværket"
      "Når dit CV overdriver lidt"
    ]
    answer: 0
    right: "Præcis. Modellen blev en stræber der pluggede facit i stedet for at forstå."
    wrong: "Overfitting = den pluggede træningsdata udenad og dumper til eksamen på nyt data."
  }
  {
    q: "Hvem fik Turing-prisen 2018 som 'the godfathers of deep learning'?"
    options: [
      "Hinton, Bengio & LeCun"
      "Turing, von Neumann & Lovelace"
      "Musk, Altman & Zuckerberg"
      "Mor, far & WiFi-routeren"
    ]
    answer: 0
    right: "Korrekt! Geoffrey Hinton, Yoshua Bengio og Yann LeCun."
    wrong: "Det var Hinton, Bengio & LeCun. WiFi-routeren bidrog dog moralsk."
  }
  {
    q: "Hvad er 'fine-tuning'?"
    options: [
      "At træne en forhåndstrænet model videre på specifikke data"
      "At justere GPU-blæserens hastighed"
      "At stemme en guitar"
      "At gøre prompten lidt pænere"
    ]
    answer: 0
    right: "Ja! Du tager en klog model og specialiserer den til din opgave."
    wrong: "Fine-tuning = videre-træning på dine egne data. Guitaren må vente."
  }
  {
    q: "Hvad er en 'context window'?"
    options: [
      "Mængden af tekst modellen kan have i 'hukommelsen' på én gang"
      "Et pop op-vindue i browseren"
      "Den tid på dagen modellen er klogest"
      "Udsigten fra serverrummet"
    ]
    answer: 0
    right: "Nemlig — løber du tør for context window, glemmer modellen starten af samtalen."
    wrong: "Det er hvor meget tekst modellen kan rumme ad gangen — ikke et browser-vindue."
  }
  {
    q: "Hvad er det primære formål med RLHF?"
    options: [
      "At gøre modellens svar mere hjælpsomme og i tråd med menneskers præferencer"
      "At gøre modellen hurtigere"
      "At komprimere modellen så den fylder mindre"
      "At lære den at spille skak"
    ]
    answer: 0
    right: "Korrekt! Reinforcement Learning from Human Feedback = menneskelig finpudsning af opførsel."
    wrong: "RLHF handler om at justere opførsel efter menneskelige præferencer — ikke om fart."
  }
]

# Slutningens 'rang-titler' bor også her i backenden.
const RANKS = [
  { min: 0,   title: "Stokastisk Papegøje",   emoji: "🦜", desc: "Du gentager AI-buzzwords uden at fortrække en fjer. Træning anbefales." }
  { min: 25,  title: "Prompt-Bonde",           emoji: "🧑‍🌾", desc: "Du dyrker spørgsmål i hånden. Respekt — men der findes traktorer." }
  { min: 45,  title: "Token-Jongløren",        emoji: "🎲", desc: "Du gætter med stil og rammer overraskende ofte rigtigt." }
  { min: 65,  title: "Gradient-Descenderen",   emoji: "📉", desc: "Du bevæger dig støt mod minimum — altså det gode slags minimum." }
  { min: 85,  title: "Prompt-Hviskeren",       emoji: "🧙", desc: "Modellerne adlyder dig. Bjørne i skoven frygter dig. Imponerende." }
  { min: 100, title: "AGI-Overherre",          emoji: "🤖", desc: "Perfekt score. Vi byder vores nye herskere hjerteligt velkommen." }
]

{|req|
  dispatch $req [
    # ---- Spørgsmål ----
    (route {path: "/api/questions"} {|req ctx|
      { questions: $QUESTIONS, ranks: $RANKS } | jok
    })

    # ---- Opret bruger ----
    (route {method: "POST" path: "/api/register"} {|req ctx|
      let body = ($in | from json)
      let u = ($body.user? | default "" | str trim)
      let p = ($body.pass? | default "")
      if ($u | is-empty) or ($p | is-empty) {
        jerr 400 "Brugernavn og kode skal udfyldes"
      } else if ($u | str length) > 24 {
        jerr 400 "Brugernavn må højst være 24 tegn"
      } else if (.cat -T users | where meta.user == $u | is-not-empty) {
        jerr 409 "Brugernavnet er allerede taget"
      } else {
        "" | .append users --meta {user: $u, hash: ($p | hash sha256)}
        let tok = (random uuid)
        "" | .append sessions --meta {token: $tok, user: $u}
        {user: $u} | jok | cookie set "sid" $tok --max-age 2592000
      }
    })

    # ---- Log ind ----
    (route {method: "POST" path: "/api/login"} {|req ctx|
      let body = ($in | from json)
      let u = ($body.user? | default "" | str trim)
      let p = ($body.pass? | default "")
      let rows = (.cat -T users | where meta.user == $u)
      if ($rows | is-empty) or (($rows | last | get meta.hash) != ($p | hash sha256)) {
        jerr 401 "Forkert brugernavn eller kode"
      } else {
        let tok = (random uuid)
        "" | .append sessions --meta {token: $tok, user: $u}
        {user: $u} | jok | cookie set "sid" $tok --max-age 2592000
      }
    })

    # ---- Log ud ----
    (route {method: "POST" path: "/api/logout"} {|req ctx|
      {ok: true} | jok | cookie delete "sid"
    })

    # ---- Hvem er jeg? ----
    (route {path: "/api/me"} {|req ctx|
      let sid = ($req | cookie parse | get sid? | default "")
      let rows = (.cat -T sessions | where meta.token == $sid)
      let user = (if ($rows | is-empty) { null } else { $rows | last | get meta.user })
      {user: $user} | jok
    })

    # ---- Indsend score (kræver login) ----
    (route {method: "POST" path: "/api/score"} {|req ctx|
      let body = ($in | from json)
      let sid = ($req | cookie parse | get sid? | default "")
      let rows = (.cat -T sessions | where meta.token == $sid)
      let user = (if ($rows | is-empty) { null } else { $rows | last | get meta.user })
      if ($user | is-empty) {
        jerr 401 "Du skal være logget ind for at gemme din score"
      } else {
        "" | .append scores --meta {
          user: $user
          score: ($body.score? | default 0)
          correct: ($body.correct? | default 0)
          total: ($body.total? | default 0)
          at: (date now | format date "%Y-%m-%dT%H:%M:%SZ")
        }
        {ok: true, user: $user} | jok
      }
    })

    # ---- Leaderboard (bedste score pr. bruger) ----
    (route {path: "/api/leaderboard"} {|req ctx|
      let frames = (.cat -T scores)
      let board = (if ($frames | is-empty) { [] } else {
        $frames | get meta
        | group-by user --to-table
        | each {|g| $g.items | sort-by score | last }
        | sort-by score --reverse
        | first 15
        | select user score correct total at
      })
      $board | jok
    })

    # ---- Statiske filer (fallback index.html) ----
    (route true {|req ctx|
      .static "public" $req.path --fallback "index.html"
    })
  ]
}
