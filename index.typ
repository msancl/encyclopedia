// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Encyclopedia of the Actuary],
  author: "Mateo Sanclemente Tellez",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
  supplement-chapter: "Chapter",
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Preface]
<preface>
Hello!

= Mathematics and Programming Toolbox
<mathematics-and-programming-toolbox>
== Exponential series
<sec-exponential-series>
The exponential function has the power-series expansion

$ e^x = sum_(k = 0)^oo frac(x^k, k !) = 1 + x + frac(x^2, 2 !) + frac(x^3, 3 !) + dots.h.c . $

Therefore, for any constant $lambda$,

$ sum_(k = 0)^oo frac(lambda^k, k !) = e^lambda . $

= Probability and statistics
<probability-and-statistics>
This chapter is primarily based on #cite(<wackerly2008>, form: "prose").

== Probability
<probability>
=== Foundations
<foundations>
An #strong[experiment] is the process by which an observation is made.

A statistical experiment involves the observation of a #strong[sample] selected from a larger body of data, existing or conceptual, called a #strong[population].

When an experiment is performed, it can result in one or more outcomes, which are called #strong[events].

A #strong[simple] event is an event that cannot be decomposed. Because sets are collection of points, we associate a distinct point, called a #strong[sample point], with each and every simple event associated with an experiment.

The letter $E$ with a subscript will be used to denote a simple event or the corresponding sample point.

The #strong[sample space] associated with an experiment is the set consisting of all possible sample points. A sample space will be denoted by $S$.

A #strong[discrete] sample space is one that contains either a finite or a countable number of distinct sample points.

An #strong[event] in a discrete sample space $S$ is a collection of sample points---that is, any subset of $S$.

Suppose $S$ is a sample space associated with an experiment. To every event $A$ in $S$ ($A$ is a subset of $S$), we assign a number, $P\(A\)$, called the #strong[probability] of $A$, so that the following axioms hold:

#block[
Axiom 1: $P\(A\)gt.eq 0$. \ Axiom 2: $P\(S\)= 1$. \ Axiom 3: If $A_1\,A_2\,A_3\,dots.h$ form a sequence of pairwise mutually exclusive events in $S$ (that is, $A_i inter A_j = nothing$ if $i eq.not j$), then

$ P\(A_1 union A_2 union A_3 union dots.h\)= sum_(i = 1)^oo P\(A_i\). $

]
We can easily show that Axiom 3, which is stated in terms of an infinite sequence of events, implies a similar property for a finite sequence.

Specifically, if $A_1\,A_2\,dots.h\,A_n$ are pairwise mutually exclusive events, then $ P\(A_1 union A_2 union A_3 union dots.h.c union A_n\)= sum_(i = 1)^n P\(A_i\). $

If $A$ is an event, then $ P\(A\)= 1 - P\(overline(A)\). $

=== Useful results from the theory of combinatorial analysis
<useful-results-from-the-theory-of-combinatorial-analysis>
With $m$ elements $a_1\,a_2\,dots.h\,a_m$ and $n$ elements $b_1\,b_2\,dots.h\,b_n$, it is possible to form $m n = m times n$ pairs containing one element from each group.

#align(center)[#box(image("probability-statistics/images/mn-rule.png", width: 35.0%))]
The $m n$ rule can be extended to any number of sets. Given three sets of elements---$a_1\,a_2\,dots.h\,a_m\;b_1\,b_2\,dots.h\,b_n\;$ and $c_1\,c_2\,dots.h\,c_p$---the number of distinct triplets containing one element from each set is equal to $m n p$.

An #strong[ordered arrangement] of $r$ distinct objects is called a #strong[permutation]. The number of ways of ordering $n$ distinct objects taken $r$ at time will be designated by the symbol $P_r^n$. In a permutation, the order matters: arranging the same objects in a different order gives a different permutation.

$ P_r^n = n\(n - 1\)\(n - 2\)dots.h.c\(n - r + 1\)= frac(n !, \(n - r\)!) . $

The number of ways of #strong[partitioning] $n$ distinct objects into $k$ distinct groups containing $n_1\,n_2\,dots.h\,n_k$ objects, respectively, where each object appears in exactly one group and $sum_(i = 1)^k n_i = n$, is

$ N = binom(n, n_1 #h(0em) n_2 #h(0em) dots.h.c #h(0em) n_k) = frac(n !, n_1 ! n_2 ! dots.h.c n_k !) . $

The terms $binom(n, n_1 #h(0em) n_2 #h(0em) dots.h.c #h(0em) n_k)$ are often called #strong[multinomial coefficients] because they occur in the expansion of the multinomial term $y_1 + y_2 + dots.h.c + y_k$ raised to the $n$th power:

$ \(y_1 + y_2 + dots.h.c + y_k\)^n= sum binom(n, n_1 #h(0em) n_2 #h(0em) dots.h.c #h(0em) n_k) y_1^(n_1) y_2^(n_2) dots.h.c y_k^(n_k)\, $

where this sum is taken over all $n_i = 0\,1\,dots.h\,n$ such that $n_1\,n_2 + dots.h.c + n_k = n$.

Additional explanation
This sum literally means: go through every possible combination of exponents $n_1\,n_2\,dots.h.c\,n_k$ that add up to $n$, and create one term for each combination.

For example, consider

$ \(y_1 + y_2 + y_3\)^3. $

The possible exponent combinations $\(n_1\,n_2\,n_3\)$ must satisfy

$ n_1 + n_2 + n_3 = 3 . $

So the summation runs over

$ \(3\,0\,0\)\,med\(0\,3\,0\)\,med\(0\,0\,3\)\, $

$ \(2\,1\,0\)\,med\(2\,0\,1\)\,med\(1\,2\,0\)\,med\(0\,2\,1\)\,med\(1\,0\,2\)\,med\(0\,1\,2\)\, $

and

$ \(1\,1\,1\). $

Therefore,

$ \(y_1 + y_2 + y_3\)^3= sum_(n_1 + n_2 + n_3 = 3\
n_1\,n_2\,n_3 gt.eq 0) binom(3, n_1 #h(0em) n_2 #h(0em) n_3) y_1^(n_1) y_2^(n_2) y_3^(n_3) . $

Expanding term by term gives

$ \(y_1 + y_2 + y_3\)^3=  & y_1^3 + y_2^3 + y_3^3 + 3 y_1^2 y_2 + 3 y_1^2 y_3 + 3 y_1 y_2^2\
 & + 3 y_2^2 y_3 + 3 y_1 y_3^2 + 3 y_2 y_3^2 + 6 y_1 y_2 y_3 . $

The number of #strong[combinations] of $n$ objects taken $r$ at a time is the number of subsets, each of size $r$, that can be formed from the $n$ objects. This number will be denoted by $C_r^n$ or $binom(n, r)$.

$ C_r^n = binom(n, r) = binom(n, r #h(0em) n - r) = frac(n !, r !\(n - r\)!) . $

Let $N$ and $n$ represent the numbers of elements in the population and sample, respectively. If the sampling is conducted in such a way that each of the $binom(N, n)$ samples has an equal probability of being selected, the sampling is said to be random, and the result is said to be a #strong[random sample].

=== Conditional probability
<conditional-probability>
The #strong[conditional probability] of an event $A$, given that an event $B$ has occurred, is equal to $ P\(A\|B\)= frac(P\(A inter B\), P\(B\))\, $

provided $P\(B\)> 0$.

Two events $A$ and $B$ are said to be #strong[independent] if any one of the following holds:

$  & P\(A\|B\)= P\(A\)\,\
 & P\(B\|A\)= P\(B\)\,\
 & P\(A inter B\)= P\(A\)P\(B\). $

Otherwise, the events are said to be dependent.

The probability of the #strong[union] of two events $A$ and $B$ is

$ P\(A union B\)= P\(A\)+ P\(B\)- P\(A inter B\). $

If $A$ and $B$ are mutually exclusive events, $P\(A inter B\)= 0$.

For some positive integer $k$, let the sets $B_1\,B_2\,dots.h\,B_k$ be such that

#block[
+ $S = B_1 union B_2 union dots.h.c union B_k$.
+ $B_i inter B_j = nothing$, for $i eq.not j$.

]
Then the collection of sets ${ B_1\,B_2\,dots.h\,B_k }$ is said to be a #strong[partition] of $S$.

Assume that ${ B_1\,B_2\,dots.h\,B_k }$ is a partition of $S$ such that $P\(B_i > 0\)$ for $i = 1\,2\,dots.h\,k$. Then for any event $A$

$ P\(A\)= sum_(i = 1)^k P\(A\|B_i\)P\(B_i\). $

#strong[Bayes' Rule]: $ P\(B_j\|A\)= frac(P\(A inter B_j\), P\(A\)) = frac(P\(A\|B_j\)P\(B_j\), sum_(i = 1)^k P\(A\|B_i\)P\(B_i\)) . $

== Random variables
<random-variables>
A #strong[random variable] is a function that assigns a real number to each possible outcome of a random experiment.

Mathematically, if $S$ is the sample space, then a random variable $Y$ is a function

$ Y : S arrow.r bb(R) . $

Thus, for every sample point $s in S$, the random variable assigns a value

$ Y\(s\)in bb(R) . $

=== Discrete random variables
<discrete-random-variables>
A random variable $Y$ is said to be #strong[discrete] if it can assume only a finite or countably infinite number of distinct values.

Notionally, we will use an #emph[uppercase letter], such as $Y$, to denote a #emph[random variable] and a #emph[lowercase letter], such as $y$, to denote a #emph[particular value] that a random variable may assume.

The expression $\(Y = y\)$ can be read, #emph[the set of all points in $S$ assigned the value $y$ by the random variable $Y$].

The probability that $Y$ takes on the value $y\,P\(Y = y\)$, is defined as the sum of the probabilities of all sample points in $S$ that are assigned the value $y$. We will sometimes denote $P\(Y = y\)$ by $p\(y\)$, which is called the #strong[probability function] for $Y$.

The #strong[probability distribution] for a discrete variable $Y$ can be represented by a formula, a table, or a graph that provides $p\(y\)= P\(Y = y\)$ for all $y$.

For any discrete probability distribution, the following must be true:

+ $0 lt.eq p\(y\)lt.eq 1$ for all $y$.
+ $sum_y p\(y\)= 1$, where the summation is over all values of $y$ with nonzero probability.

The #strong[expected value] of $Y$, $E\(Y\)$, is defined to be

$ E\(Y\)= sum_y y p\(y\). $

Let $g\(Y\)$ be a real-valued function of $Y$. Then the expected value of $g\(Y\)$ is given by

$ E\[g\(y\)\]= sum_y g\(y\)p\(y\). $

If $Y$ is a r.v. with mean $E\(Y\)= mu$, the #strong[variance] of $Y$ is defined to be the expected value of $\(Y - mu\)^2$. That is,

$ V\(Y\)= E\[\(Y - mu\)^2\]= E\(Y^2\)- mu^2 . $

The #strong[standard deviation] of $Y$ is the positive square root of $V\(Y\)$.

If $p\(y\)$ is an accurate characterization of the population frequency distribution, then $E\(Y\)= mu$, $V\(Y\)= sigma^2$, the #emph[population variance], and $sigma$ is the #emph[population standard deviation].

If $c$ is a constant, then

$  & E\[c\]= c\,\
 & E\[c g\(Y\)\]= c E\[g\(Y\)\]. $

Let $g_1\(Y\)\,g_2\(Y\)\,dots.h\,g_k\(Y\)$ be $k$ functions of $Y$. Then,

$ E\[g_1\(Y\)+ g_2\(Y\)+ dots.h.c + g_k\(Y\)\]= E\[g_1\(Y\)\]+ E\[g_2\(Y\)\]+ dots.h.c + E\[g_k\(Y\)\]. $

Some exercises
+ Wackerly 3.19 --- An insurance company issues a one-year \$1000 policy insuring against an occurrence $A$ that historically happens to 2 out of every 100 owners of the policy. Administrative fees are \$15 per policy and are not part of the company's profit. How much should the company charge for the policy if it requires that the expected profit per policy be \$50 ?

  Answer: If $C$ is the premium for the policy, the company's profit is $C - 15$ if $A$ does not occur and $C - 15 - 1000$ if $A$ does occur.

  $ E\[upright("Profit")\]= 0.98\(C - 15\)+ 0.02\(C - 15 - 1000\). $

  $ 0.98\(C - 15\)+ 0.02\(C - 15 - 1000\)= 50 arrow.l.r.double C = 85 . $

+ Wackerly 3.29 --- If $Y$ is a discrete random variable that assigns positive probabilities to only the positive integers, show that $ E\(Y\)= sum_(k = 1)^oo P\(Y gt.eq k\)= sum_(y = 1)^oo y p\(y\). $

  Answer: Notice that for a positive integer $y$,

  $ y = sum_(k = 1)^y 1 . $

  Thus, $ E\(Y\)= sum_(y = 1)^oo (sum_(k = 1)^y 1) P\(Y = y\). $

  So $ E\(Y\)= sum_(y = 1)^oo sum_(k = 1)^y P\(Y = y\). $

  Now we reverse the order of summation. For a fixed $k$, the possible $y$'s are $y = k\,k + 1\,k + 2\,dots.h$ because $k lt.eq y$.

  Hence,

  $ E\(Y\)= sum_(k = 1)^oo sum_(y = k)^oo P\(Y = y\). $

  But,

  $ sum_(y = k)^oo P\(Y = y\)= P\(Y gt.eq k\). $

  Therefore,

  $ E\(Y\)= sum_(k = 1)^oo P\(Y gt.eq k\). $

+ Wackerly 3.33 --- Let $Y$ be a discrete random variable with mean $mu$ and variance $sigma^2$. If $a$ and $b$ are constants, prove that

  #strong[1] $E\(a Y + b\)= a E\(Y\)+ b = a mu + b$.

  Answer: Starting from the definition of expectation of a function of a discrete random variable:

  $ E\[g\(Y\)\]= sum_y g\(y\)p\(y\). $

  Here, $g\(Y\)= a Y + b$. Therefore,

  Now, $sum_y y p\(y\)= E\(Y\)= mu\,$ and because the probabilities of all possible values of $Y$ sum to 1, $sum_y p\(y\)= 1$.

  Therefore,

  $ E\(a Y + b\)= a mu + b . $

  #strong[2] $V\(a Y + b\)= a^2 V\(Y\)= a^2 sigma^2$.

  Answer: Recall the definition of variance: $V\(X\)= E\[\(X - E\(X\)\)^2\]$.

  Let $X = a Y + b$. We already know that $E\(X\)= a mu + b$.

  Therefore,

==== The Binomial probability distribution
<the-binomial-probability-distribution>
A #strong[binomial experiment] possesses the following properties:

+ The experiment consists of a fixed number, $n$, of identical trials.
+ Each trial results in one of two outcomes: success, $S$ or failure, $F$.
+ The probability of success on a single trial is equal to some value $p$ and remains the same from trial to trial. The probability of a failure is equal to $q =\(1 - p\)$.
+ The trials are independent.
+ The random variable of interest is $Y$, the number of successes observed during the $n$ trials.

A random variable $Y$ is said to have a binomial distribution based on $n$ trials with success probability $p$ if and only if

$ p\(y\)= binom(n, y) p^y q^(n - y)\,quad y = 0\,1\,2\,dots.h\,n upright(" and ") 0 lt.eq p lt.eq 1 . $

Proof
Each sample point in the sample space can be characterized by an $n$-tuple involving the letters $S$ and $F$, corresponding to success and failure.

A typical sample point would thus appear as

$ underbrace(S S F S F F F S F S dots.h.c F S, n upright(" positions"))\, $

where the letter in the $i$th position indicates the outcome of the $i$th trial.

Let's now consider a particular sample point corresponding to $y$ successes and hence contained in the numerical event $Y = y$. This sample point,

$ underbrace(S S S S S dots.h.c S S S, y) underbrace(F F F dots.h.c F F, n - y)\, $

represents the intersection of $n$ independent events (the outcomes of the $n$ trials), in which there were $y$ successes followed by $\(n - y\)$ failures.

Because the trials were independent and the probability of $S$, $p$, stays the same from trial to trial, the probability of this sample point is

$ underbrace(p p p p p dots.h.c p p p, y upright("(") t e r m s\)) underbrace(q q q dots.h.c q q, n - y upright("(") t e r m s\)) = p^y q^(n - y) $

Every other sample point in the event $Y = y$ can be represented as an $n$-tuple containing $y$ $S$'s and $\(n - y\)F$'s in some order. Any such sample point also has probability $p^y q^(n - y)$.

Because the number of distinct $n$-tuples that contain $y$ $S$'s and $\(n - y\)$ $F$'s is

$ binom(n, y) = frac(n !, y !\(n - y\)!)\, $

it follows that event $\(Y = y\)$ is made up of $binom(n, y)$ sample points, each with probability $p^y q^(n - y)$, and that $p\(y\)= binom(n, y) p^y q^(n - y)\,quad y = 0\,1\,2\,dots.h\,n$.

The term #emph[binomial experiment] derives from the fact each trial results in one of two possible outcomes and that the probabilities $p\(y\)\,y = 0\,1\,2\,dots.h\,n$, are terms of the #strong[binomial expansion]:

$ \(q + p\)^n= binom(n, 0) q^n + binom(n, 1) p^1 q^(n - 1) + binom(n, 2) p^2 q^(n - 2) + dots.h.c + binom(n, n) p^n . $

Example
For example,

$ \(q + p\)^4= binom(4, 0) q^4 + binom(4, 1) p q^3 + binom(4, 2) p^2 q^2 + binom(4, 3) p^3 q + binom(4, 4) p^4 . $

Since

$ binom(4, 0) = 1\,#h(2em) binom(4, 1) = 4\,#h(2em) binom(4, 2) = 6\,#h(2em) binom(4, 3) = 4\,#h(2em) binom(4, 4) = 1\, $

we obtain

$ \(q + p\)^4= q^4 + 4 p q^3 + 6 p^2 q^2 + 4 p^3 q + p^4 . $

Binomial probabilities can also be found using R. If $Y$ has a binomial distribution based on $n$ trials with success probability $p$, $P\(Y = y_0\)= p\(y_0\)$ can be found using the command #NormalTok("dbinom(y0, n, p)");, whereas $P\(Y lt.eq y_0\)$ is found by using the command #NormalTok("pbinom(y_0, n, p)");.

Let $Y$ be a binomial random variable based on $n$ trials and success probability $p$. Then

$ mu = E\(Y\)= n p quad upright(" and ") quad sigma^2 = V\(Y\)= n p q . $

Some exercises
+ Wackerly 3.35 --- Suppose that there are $N = 5000$ voters in the population, 40% of whom favor Jones. Identify the event #emph[favors Jones] as a success $S$. It is evident that the probability of $S$ on trial 1 is $0.40$. Consider the event $B$ that $S$ occurs on the second trial. Then $B$ can occur in two ways: The first two trials are both successes #emph[or] the first trial is a failure and the second is a success. Show that $P\(B\)= 0.4 .$ What is $P\(B\|upright(" the first trial is ") S\)?$ Does this #emph[conditional] probability differ markedly from $P\(B\)$?

  Answer: There are $0.4\(5000\)= 2000$ voters who favor Jones, while 3000 do not. Let $S_1$: first voter favors Jones, and $B = S_2$: second voter favors Jones.

  The second voter can favor Jones in exactly two mutually exclusive ways:

  $ \(S_1 inter S_2\)quad upright(" or ") quad\(overline(S_1) inter S_2\). $

  Therefore, $ P\(B\)= P\(S_1 inter S_2\)+ P\(overline(S_1) inter S_2\). $

  For the first path,

  $ P\(S_1\)= 2000 / 5000\, $

  and after selecting a Jones supporter first, 1999 Jones supporters remain among 4999 voters:

  $ P\(S_2\|S_1\)= 1999 / 4999 . $

  Hence,

  $ P\(S_1 inter S_2\)= P\(S_2\|S_1\)P\(S_1\)= 1999 / 4999 2000 / 5000 . $

  For the second path,

  $ P\(overline(S_1)\)= 3000 / 5000 upright(" and ") P\(S_2\|overline(S_1)\)= 2000 / 4999 . $

  Hence,

  $ P\(overline(S_1) inter S_2\)= 2000 / 4999 3000 / 5000 . $

  Putting everything together,

  $ P\(B\)= 1999 / 4999 2000 / 5000 + 2000 / 4999 3000 / 5000 = 0.4 . $

  So although the first voter is removed, the unconditional probability that the second voter favors Jones is still 0.4.

  Now the exercise asks for $P\(B\|S_1\)$, which we calculated as $1999 / 4999 approx 0.39988$.

  The difference is only about 0.00012 so it is not markedly different. The important conceptual point is that the trials are not exactly independent, because $P\(B\|S_1\)eq.not P\(B\)$. But because the population is very large relative to one draw, the dependence is negligible. This is why sampling without replacement from a very large population can be treated as approximately binomial.

+ Wackerly 3.36(a) --- A meteorologist in Denver recorded $Y$ = the number of days of rain during a 30-day period. Does $Y$ have a binomial distribution ? If so, are the values of both $n$ and $p$ given?

  Answer: Not necessarily binomial because consecutive days are often related.

+ Wackerly 3.36(b) --- A market research firm has hired operators who conduct telephone surveys. A computer is used to randomly dial a telephone number, and the operator asks the answering person whether she has time to answer some questions. Let \$Y = \$ the number of calls made until the first person replies that she is willing to answer the questions. Is this a binomial experiment? Explain.

  Answer: No because the number of trials $n$ must be fixed in advance.

+ Wackerly 3.48 --- A missile protection system consists of $n$ radar sets operating independently, each with a probability of 0.9 of detecting a missile entering a zone that is covered by all of the units.

  + If $n$ = 5 and a missile enters the zone, what is the probability that exactly four sets detect the missile? At least one set?

  Answer: Let \$Y = \$number of radar sets that detect the missile. Since the radar sets operate independently and each detects the missile with probability $p = 0.9$, we have $Y tilde.op "Bin"\(n\,0.9\)$.

  For exactly four sets detecting the missile: $ P\(Y = 4\)= binom(5, 4)\(0.9\)^4\(0.1\)^1= 0.32805 . $

  For at least one set detecting the missile, it is easier to use the complement:

  $ P\(Y gt.eq 1\)= 1 - P\(Y = 0\)= 1 -\(0.1\)^5= 0.99999 . $

  #block[
  #set enum(numbering: "1.", start: 2)
  + How large must be $n$ if we require that the probability of detecting a missile that enters the zone be 0.999?
  ]

  $ P\(Y\)gt.eq 0.999 arrow.l.r.double 1 -\(0.1\)^ngt.eq 0.999 arrow.l.r.double n gt.eq 3 . $

  Indeed, $ P\(upright("at least one detection")\)= 1 -\(0.1\)^3= 1 - 0.001 = 0.999 . $

+ Wackerly 3.58 --- A particular sale involves four items randomly selected from a large lot that is known to contain 10% defectives. Let $Y$ denote the number of defectives among the four sold. The purchase of the items will return the defectives for repair, and the repair cost is given by $C = 3 Y^2 + Y + 2$. Find the expected repair cost.

  Answer: With $Y tilde.op "Bin"\(4\,0.1\)$, we want $E\(C\)= 3 Y^2 + Y + 2 = E\(C\)= 3 E\(Y^2\)+ E\(Y\)+ 2 .$

  Since $E\(Y\)= n p = 0.4$, and $E\(Y^2\)= sigma^2 + mu^2 = n p q +\(n p\)^2= 0.52\,$

  $ E\(C\)= 3\(0.52\)+ 0.4 + 2 = 3.96\$. $

==== The Geometric probability distribution
<the-geometric-probability-distribution>
The random variable with the geometric probability distribution is associated with an experiment involving identical and independent trials, each of which can result in one of two outcomes: success or failure. The probability of success is equal to $p$ and is constant from trial to trial. However, instead of the number of successes that occur in $n$ trials, the geometric r.v. $Y$ is the number of the trial on which the first success occurs.

A random variable $Y$ is said to have a #strong[geometric] probability distribution if and only if

$ p\(y\)= q^(y - 1) p\,#h(2em) y = 1\,2\,3\,dots.h\,quad 0 lt.eq p lt.eq 1 . $

This distribution is often used to model distributions of lengths of waiting times. For example, suppose that a commercial aircraft engine is serviced periodically so that its various parts are replaced at different points in time and hence are of varying ages. Then the probability of engine malfunction, $p$, during any randomly observed one-hour interval of operation might be the same as for any other one-hour interval. (If the entire engine simply aged continuously without maintenance, we might expect $P$\(failure in next hour) to increase as the engine gets older). The length of time prior to engine malfunction is the number of one-hour intervals, $Y$, until the first malfunction.

If $Y$ is a rv with a geometric distribution,

$ mu = E\(Y\)= 1 / p quad upright(" and ") quad sigma^2 = V\(Y\)= frac(1 - p, p^2) . $

$P\(Y = y_0\)= p\(y_0\)$ can be found using the R command #NormalTok("dgeom(y0-1, p)"); whereas $P\(Y < = y_0\)$ is found by using the R command #NormalTok("pgeom(y0-1,p)");.

Note that the argument in these commands is the value $y_0 - 1$, not the value $y_0$, because some authors prefer to define the geometric distribution to be that of the random variable $Y^(*) =$ #emph[the number of failures before the first success].

Some exercises
+ Wackerly 3.70 --- An oil prospector will drill a succession of holes in a given area to find a productive well. The probability that he is successful on a given trial is \.2.

  + What is the probability that the third hole drilled is the first to yield a productive well?

  Answer: $ p\(3\)= 0.8^2 0.2 = 0.128 . $

  #block[
  #set enum(numbering: "1.", start: 2)
  + If the prospector can afford to drill at most ten wells, what is the probability that he will fail to find a productive well?
  ]

  Answer: $ 0.8^10 = 0.1074 . $

+ Wackerly 3.71 --- Let $Y$ denote a geometric rv with probability of success $p$. Show that for positive integers $a$ and $b$, $ P\(Y > a + b\|Y > a\)= q^b = P\(Y > b\). $

  Answer: $ P\(Y > a + b\|Y > a\)= frac(P\(Y > a + b\), P\(Y > a\)) = q^(a + b) / q^a = q^b . $

  This result implies that, for example, $P\(Y > 7\|Y > 2\)= P\(Y > 5\)$. This property is called the #strong[memoryless property] of the geometric distribution. Past failures do not affect the distribution of the remaining waiting time.

+ Wackerly 3.88 --- If $Y$ is a geometric rv, define $Y^(*) = Y - 1$. If $Y$ is interpreted as the number of the trial on which the first success occurs, then $Y^(*)$ can be interpreted as the number of failures before the first success. If $Y^(*) = Y - 1\,P\(Y^(*) = y\)= P\(Y - 1 = y\)= P\(Y = y + 1\)$ for $y = 0\,1\,2\,dots.h .$ Show that $ P\(Y^(*) = y\)= q^y p\,quad y = 0\,1\,2\,dots.h . $

  Answer: Using the ordinary geometric probability distribution, $P\(Y = k\)= q^(k - 1) p .$

  Here $k = y + 1$, so $ P\(Y = y + 1\)= q^(\(y + 1\)- 1) p = q^y p . $

  Therefore, $ P\(Y^(*) = y\)= q^y p\,quad y = 0\,1\,2\,dots.h . $

  The probability distribution of $Y^(*)$ could sometimes be used by actuaries as a model for the distribution of the number of insurance claims made in a specific time period.

  Suppose $N$= number of insurance claims made by a policyholder during one year. Possible values are naturally $N = 0\,1\,2\,3\,dots.h .$, just like $Y^(*)$. An actuary could therefore model $N tilde.op "Geom"_0\(p\).$

==== The Negative Binomial probability distribution
<the-negative-binomial-probability-distribution>
Again we focus on independent and identical trials, each of which results in one of two outcomes: success or failure. The probability $p$ of success stays the same from trial to trial.

The geometric distribution handles the case where we are interested in the number of the trial on which the first success occurs. What if we are interested in knowing the number of the trial on which the second, third, or fourth success occurs?

The distribution that applies to the random variable $Y$ equal to the number of the trial on which the $r$th success occurs ($r = 2\,3\,4$ etc.) is the negative binomial distribution.

A random variable $Y$ is said to have a #strong[negative binomial] probability distribution if and only if

$ p\(y\)= binom(y - 1, r - 1) p^r q^(y - r)\,#h(2em) y = r\,r + 1\,r + 2\,dots.h\,quad 0 lt.eq p lt.eq 1 . $

Proof
Let us select fixed values for $r$ and $y$ and consider events $A$ and $B$, where $ A = { upright("the first ")\(y - 1\)upright(" trials contain ")\(r - 1\)upright(" successes") } $

and

$ B = { upright("trial ") y upright(" results in a success") } . $

Because w assume that the trials are independent, it follows that $A$ and $B$ are independent events, and previous assumptions imply that $P\(B\)= p$.

Therefore,

$ p\(y\)= p\(Y = y\)= P\(A inter B\)= P\(A\)times P\(B\). $

Notice that $P\(A\)$ is 0 if $y < r$. If $y gt.eq r$, our previous work with the binomial distribution implies that

$ P\(A\)= binom(y - 1, r - 1) p^(r - 1) q^(y - r) . $

Finally,

$ P\(A\)times P\(B\)= p\(y\)= binom(y - 1, r - 1) p^r q^(y - r)\,#h(2em) y = r\,r + 1\,r + 2\,dots.h . $

If $r = 2\,3\,4\,dots.h$ and $Y$ has a negative binomial distribution with success probability $p$, $P\(Y = y_0\)= p\(y_0\)$ can be found by using the R command #NormalTok("dnbinom(y0-r, r, p)");. If we wanted to use R to obtain the probability of obtaining the third success on the fifth trial, $p\(5\)$, we use the command #NormalTok("dnbinom(2, 3, 0.2)");, if the success probability of a single trial is 0.2.

Alternatively, $P\(Y lt.eq y_0\)$ is found by using the R command #NormalTok("pbinom(y0-r, r, p)");.

Note that the first argument in these commands is the value $y_0 - r$. This is because some authors prefer to define the negative binomial distribution to be that of the random variable $Y^(*) =$ the number of failures before the $r$th success.

If $Y$ is a rv with a negative binomial distribution,

$ mu = E\(Y\)= r / p quad upright(" and ") quad sigma^2 = V\(Y\)= frac(r\(1 - p\), p^2) . $

Some exercises
+ Wackerly 3.96 --- The telephone lines serving an airline reservation office are all busy about 60% of the time.

  + If we are calling this office, what is the probability that we will complete our call on the third try?

  Answer: Here, a call is a success if we get through; $p = P\(S\)= 0.4$.

  For the third try to be the first successful one, the sequence must be $F F S$.

  This is geometric because we're waiting for the first success.

  Therefore, $ P\(Y = 3\)= q^2 p = 0.6^2 0.4 = 0.144 . $

  #block[
  #set enum(numbering: "1.", start: 2)
  + If us and a friend must both complete calls to this office, what is the probability that a total of four tries will be necessary for both of us to get through.
  ]

  Answer: Using the negative binomial formula with $r = 2$ and $y = 4$,

  $ P\(Y = 4\)= binom(4 - 1, 2 - 1) p^2 q^(4 - 2) = 0.1728 . $

+ Wackerly 3.97 --- A geological study indicates that an exploratory oil well should strike oil with probability 0.2.

  + What is the probability that the first strike comes on the third well drilled?

  Answer: $ P\(Y = 3\)= q^2 p = 0.8^2 0.2 = 0.128 . $

  #block[
  #set enum(numbering: "1.", start: 2)
  + What is the probability that the third strike comes on the seventh well drilled?
  ]

  Answer: $ P\(Y = 7\)= binom(6, 2) 0.2^3 0.8^4 approx 0.0492 . $

  #block[
  #set enum(numbering: "1.", start: 3)
  + What assumptions are necessary to obtain the answers to parts 1 and 2?
  ]

  Answer: each well has only two relevant outcomes: oil strike or no oil strike; each drilling has the same probability of success: $P\(S\)= 0.2$\; and the drillings are independent. So essentially, independent, identical Bernoulli trials with constant $p = 0.2$.

  #block[
  #set enum(numbering: "1.", start: 4)
  + Find the mean and variance of the number of wells that must be drilled if the company wants to set up three producing wells.
  ]

  Answer: Let $Y =$ number of wells drilled until the third strike.

  Then, $Y tilde.op "NegBin"\(r = 3\,p = 0.2\).$

  For a negative binomial rv, $ E\(Y\)= r / p = 3 / 0.2 = 15 . $

  So the company should expect to drill 15 wells to obtain three producing wells.

  The variance is

  $ V\(Y\)= frac(r q, p^2) = frac(3\(0.8\), 0.2^2) = 60 . $

==== The Hypergeometric probability distribution
<the-hypergeometric-probability-distribution>
Suppose that a population contains a finite number $N$ of elements that possesses one of two characteristics.

Thus, $r$ of the elements might be red and $b = N - r$, black. A sample of $n$ elements is randomly selected from the population, and the random variable of interest is $Y$, the number of red elements in the sample. This rv has what is known as the hypergeometric probability distribution.

A random variable $Y$ is said to have a #strong[hypergeometric] probability distribution if and only if

$ p\(y\)= frac(binom(r, y) binom(N - r, n - y), binom(N, n))\, $

where $y$ is an integer $0\,1\,2\,dots.h\,n$, subject to the restrictions $y lt.eq r$ and $n - y lt.eq N - r$.

Suppose that a population of size $N$ consists of $r$ units with the attribute and $N - r$ without. If a sample of size $n$ is taken, without replacement, and $Y$ is the number of items with the attribute in the sample, $P\(Y = y_0\)= p\(y_0\)$ can be found by using the R command #NormalTok("dhyper(y0, r, N-r, n)");. Alternatively, $P\(Y lt.eq y_0\)$ is found by using the R command #NormalTok("phyper(y0, r, N-r, n)");.

If $Y$ is a random variable with a hypergeometric distribution,

$ mu = E\(Y\)= frac(n r, N) quad upright(" and ") quad sigma^2 = V\(Y\)= n (r / N) (frac(N - r, N)) (frac(N - n, N - 1)) . $

Although the mean and the variance of the hypergeometric random variable seem to be complicated, they bear a striking resemblance to the mean and variance of a binomial rv. Indeed, if we define $p = r / N$ and $q = 1 - p = frac(N - r, N)$, we can re-express the mean and variance of the hypergeometric as $mu = n p$ and

$ sigma^2 = n p q (frac(N - n, N - 1)) . $

We can view the factor $frac(N - n, N - 1)$ in $V\(Y\)$ as an adjustment that is appropriate when $n$ is large relative to $N$.

For fixed $n$, as $N arrow.r oo$,

$ frac(N - n, N - 1) arrow.r 1 . $

The hypergeometric probability function converges to the binomial probability function as $N$ becomes large:

$ lim_(N arrow.r oo) frac(binom(r, y) binom(N - r, n - y), binom(N, n)) = binom(n, y) p^y\(1 - p\)^(n - y). $

where $r / N = p .$

Some exercises
+ Wackerly 3.105 --- A group of eight candidates for three local teaching positions consisted of five who had enrolled in paid internships and three who enrolled in traditional student teaching programs. All eight candidates appear to be equally qualified, so three are randomly selected to fill the open positions. Let $Y$ be the number of internship trained candidates who are hired.

  #block[
  #set enum(numbering: "a.", start: 1)
  + Does $Y$ have a binomial or hypergeometric distribution? Why ?
  ]

  Answer: It is hypergeometric because the candidates are selected without replacement from a finite population. Once somebody is hired, they cannot be selected again, so the successive selections are not independent.

  Thus, $ Y tilde.op "Hypergeometric"\(N = 8\,r = 5\,n = 3\). $

  The probability distribution is

  $ P\(Y = y\)= frac(binom(5, y) binom(3, 3 - y), binom(8, 3)) . $

  #block[
  #set enum(numbering: "a.", start: 2)
  + Find the probability that two or more internship trained candidates are hired.
  ]

  Answer: We want $P\(Y gt.eq 2\)= P\(Y = 2\)+ P\(Y = 3\)$ since only 3 people are hired.

  For exactly 2 internship-trained candidates:

  $ P\(Y = 2\)= frac(binom(5, 2) binom(3, 1), binom(8, 3)) = 30 / 56 . $

  For exactly 3 intership-trained candidates:

  $ P\(Y = 2\)= frac(binom(5, 3) binom(3, 0), binom(8, 3)) = 10 / 56 . $

  Hence,

  $ P\(Y gt.eq 2\)= 40 / 56 = 5 / 7 approx 0.7143 . $

  #block[
  #set enum(numbering: "a.", start: 3)
  + What are the mean and standard deviation of $Y$?
  ]

  Answer: Using $E\(Y\)= frac(n r, N)$, we obtain $ 15 / 8 = 1.875 . $

  For the variance, $V\(Y\)$ gives us $225 / 448$. The standard deviation is

  $ sigma = sqrt(V\(Y\)) = sqrt(225 / 448) approx 0.7087 . $

+ Wackerly 3.108 --- A shipment of 20 cameras includes 3 that are defective. What is the minimum number of cameras that must be selected if we require that $P\(upright("at least ") 1 upright(" defective")\)gt.eq 0.8$?

  Answer: We need $1 - P\(Y = 0\)gt.eq 0.8$, or equivalently $P\(Y = 0\)lt.eq 0.2 .$

  If $Y$ is the number of defectives selected, then

  $ P\(Y = 0\)= frac(binom(3, 0) binom(17, n), binom(20, n)) = binom(17, n) / binom(20, n) . $

  Now, we have to test increasing values of $n$.

  For $n = 7$,

  $ P\(Y = 0\)= binom(17, 7) / binom(20, 7) approx 0.2509\, $

  so

  $ P\(Y gt.eq 1\)= 1 - 0.2509 = 0.7491 < 0.8\, $

  which is not enough.

  But for $n = 8$,

  $ P\(Y = 0\)= binom(17, 8) / binom(20, 8) approx 0.1930 . $

  Therefore,

  $ P\(Y gt.eq 1\)= 1 - 0.19309 = 0.8070 > 0.8 . $

  Since $n = 7$ fails but $n = 8$ works, the minimum is $n = 8$.

+ Wackerly 3.119 --- Cards are dealt at random and without replacement from a standard 52 card deck. What is the probability that the second king is dealt on the fifth card?

  Answer: For the second king to be dealt on the fifth card, two things must happen; exactly 1 king among cards 1-4 and then card 5 must be a king.

  First, the probability of exactly one king among the first four cards is hypergeometric:

  $ P\(upright("1 king in first 4")\)= frac(binom(4, 1) binom(48, 3), binom(52, 4)) . $

  If exactly one king appeared in those first four cards, then there are 48 cards remaining, including 3 kings. Therefore,

  $ P\(upright("5th card is king ")\|upright(" 1 king in first 4")\)= 3 / 48 . $

  If we multiply both results, we obtain $ P\(upright("second king on card 5")\)= frac(binom(4, 1) binom(48, 3), binom(52, 4)) 3 / 48 approx 0.01597 . $

+ Wackerly 3.120 --- The sizes of animal populations are often estimated by using a capture-tag-recapture method. In this method $k$ animals are captured, tagged, and then released into the population. Some time later $n$ animals are captured, and $Y$, the number of tagged animals among the $n$, is noted. The probabilities associated with $Y$ are a function of $N$, the number of animals in the population, so the observed value of $Y$ contains information on this unknown $N$. Suppose that $k = 4$ animals are tagged and then released. A sample of $n = 3$ animals is then selected at random from the same population. Find $P\(Y = 1\)$ as a function of $N$. What value of $N$ will maximize $P\(Y = 1\)$?

  Answer: Because we sample from a finite population without replacement, $Y$ is hypergeometric.

  There are 4 tagged animals and $N - 4$ untagged animals.

  Therefore, $ P\(Y = 1\)= frac(binom(4, 1) binom(N - 4, 2), binom(N, 3)) . $

  Maximizing for $N$ gives $N = 11$ or $N = 12$.

==== The Poisson probability distribution
<the-poisson-probability-distribution>
Suppose that we want to find the probability distribution of the number of automobile accidents at a particular intersection during a time period of one week. At first glance this rv, the number of accidents, may not seem even remotely related to a binomial rv, but there exists an interesting relationship.

If we think of the time period, one week in this example, as being split up into $n$ subintervals, each of which is so small that at most one accident could occur in it with probability different from zero.

Denoting the probability of accident in any subinterval by $p$, we have, for all practical purposes,

$ P\(upright("no accidents occur in a subinterval")\) & = 1 - p\,\
P\(upright("one accident occurs in a subinterval")\) & = p\,\
P\(upright("more than one accident occurs in a subinterval")\) & = 0 . $

Then the total number of accidents in the week is just the total number of subintervals that contain one accident. If the occurrence of accidents can be regarded as independent from interval to interval, the total number of accidents has a binomial distribution.

It seems reasonable that as we divide the week into a greater number $n$ of subintervals, the probability $p$ of one accident in one of these shorter subintervals will decrease. Letting $lambda = n p$ and taking the limit of the binomial probability $p\(y\)= binom(n, y) p^y\(1 - p\)^(n - y)$ as $n arrow.r oo$, we have

$ lim_(n arrow.r oo) binom(n, y) p^y\(1 - p\)^(n - y) & = lim_(n arrow.r oo) frac(n\(n - 1\)dots.h.c\(n - y + 1\), y !) (lambda / n)^y (1 - lambda / n)^(n - y)\
 & = lim_(n arrow.r oo) frac(lambda^y, y !) (1 - lambda / n)^n frac(n\(n - 1\)dots.h.c\(n - y + 1\), n^y) (1 - lambda / n)^(- y)\
 & = frac(lambda^y, y !) lim_(n arrow.r oo) (1 - lambda / n)^n (1 - lambda / n)^(- y) (1 - 1 / n)\
 & #h(2em) times (1 - 2 / n) times dots.h.c times (1 - frac(y - 1, n)) . $

Noting that $ lim_(n arrow.r oo) (1 - lambda / n)^n = e^(- lambda)\, $ and all other terms to the right of the limit have a limit 1, we obtain $ p\(y\)= frac(lambda^y, y !) e^(- lambda) . $

Rv's possessing this distribution are said to have a Poisson distribution.

Because the binomial probability function converges to the Poisson, the Poisson probabilities can be used to approximate their binomial counterparts for large $n$, small $p$, and $lambda = n p$ less than, roughly, 7.

The Poisson probability distribution often provides a good model for the probability distribution of the number $Y$ of rare events that occur in space, time, volume, or any other dimension, where $lambda$ is the average value of $Y$.

A random variable $Y$ is said to have a #strong[Poisson] probability distribution if and only If

$ p\(y\)= frac(lambda^y, y !) e^(- lambda)\,#h(2em) y = 0\,1\,2\,dots.h\,quad lambda > 0 . $

If $Y$ has a Poisson distribution with mean $lambda$, $P\(Y = y_0\)= p\(y_0\)$ can be found by using the R command #NormalTok("dpois(y0,λ)");. Alternatively, $P\(Y lt.eq y_0\)$ is found by using the R command #NormalTok("ppois(y0,λ)");.

If $Y$ is a random variable possessing a Poisson distribution with parameter $lambda$, then

$ mu = E\(Y\)= lambda quad upright(" and ") quad sigma^2 = V\(Y\)= lambda . $

A common way to encounter a rv with a Poisson distribution is through a model called a #strong[Poisson process], which models events occurring randomly over time, length, area, or another continuous domain.

If events occur at a constant average rate $lambda$ per unit, then the number of occurrences $Y$ observed over $a$ units follows a Poisson distribution with mean $a lambda$:

$ Y tilde.op "Poisson"\(a lambda\). $

For example, if events occur on average at a rate of $lambda = 3$ per hour, then the number observed during two hours has mean $2 lambda = 6$.

A key assumption of a Poisson process is that counts in disjoint intervals are independent. Thus, the number of events occurring in one interval does not affect the number occurring in a separate, non-overlapping interval.

Some exercises
+ Wackerly 3.124 --- Approximately 4% of silicon wafers produced by a manufacturer have fewer than two large flaws. If $Y$, the number of flaws per wafer, has a Poisson distribution, what proportion of the wafers have more than five large flaws?

  Answer: We are told that 4% of wafers have fewer than two flaws:

  $ P\(Y < 2\)= 0.04 . $

  Since $Y$ is discrete,

  $ P\(Y < 2\)= P\(Y = 0\)+ P\(Y = 1\). $

  For a Poisson rv,

  $ P\(Y = y\)= frac(lambda^y e^(- lambda), y !) . $

  Therefore, $ P\(Y = 0\)= e^(- lambda) upright(" and ") P\(Y = 1\)= lambda e^(- lambda) . $

  Hence,

  $ e^(- lambda) + lambda e^(- lambda) = 0.04\, $

  where solving for $lambda$ gives $lambda approx 5.013$.

  Now the question asks for the proportion having more than five flaws, $P\(Y > 5\)$.

  We can use the complement:

  $ P\(Y > 5\)= 1 - P\(Y lt.eq 5\)= 1 - sum_(y = 0)^5 frac(lambda^y e^(- lambda), y !) . $

  Using our $lambda approx 5.013$,

  $ P\(Y lt.eq 5\)approx 0.6137 . $

  Therefore,

  $ P\(Y > 5\)approx 1 - 0.6137 = 0.3863 . $

+ Wackerly 3.126 --- Assume that arrivals occur according to a Poisson process with an average of seven per hour. What is the probability that exactly two customers arrive in the two-hour period of time between

  #block[
  #set enum(numbering: "a.", start: 1)
  + 2:00 PM and 4:00 PM (one continuous two-hour period)?
  ]

  Answer: For a Poisson process, over $t$ hours,

  $ N\(t\)tilde.op "Poisson"\(7 t\). $

  The exposure is 2 hours, so $lambda^(*) = 7 times 2 = 14 .$

  Thus, $N tilde.op "Poisson"\(14\).$

  We want exactly two customers:

  $ P\(N = 2\)= frac(14^2 e^(- 14), 2 !) approx 0.0000815 . $

  #block[
  #set enum(numbering: "a.", start: 2)
  + 1:00 PM and 2:00 PM or between 3:00 PM and 4:00 PM (two separate one-hour periods that total two hours)?
  ]

  Answer: Because the process is homogeneous, the arrival rate is constant over time. Therefore, only the total length of the observed intervals matters.

  The two separate one-hour intervals are disjoint and together represent 2 hours of observation, so the total numbers of arrivals has also $lambda = 14$.

  Thus, part (b) has the same distribution as part (a) and therefore the probability of exactly two arrivals is the same.

+ Wackerly 3.128 & 3.129 --- Cars arrive at a toll both according to a Poisson process with mean 80 cars per hour.

  #block[
  #set enum(numbering: "a.", start: 1)
  + If the attendant makes a one-minute phone call, what is the probability that at least 1 car arrives during the call?
  ]

  Answer: $lambda = 80$ cars/hour, and thus $lambda = 80 / 60 = 4 / 3$ cars/minute.

  For a one-minute call, $ Y tilde.op "Poisson" (4 / 3) . $

  We want $P\(Y gt.eq 1\)= 1 - P\(Y = 0\).$

  For a Poisson rv,

  $ P\(Y = 0\)= e^(- lambda) . $

  Therefore,

  $ P\(Y gt.eq 1\)= 1 - e^(- 4 / 3) approx 0.7364 . $

  #block[
  #set enum(numbering: "a.", start: 2)
  + How long can the attendant's phone call last if the probability is at least 0.4 that no cars arrive during the call?
  ]

  Answer: Let $t$ be the length of the call in minutes. During $t$ minutes, the Poisson mean is $4 / 3 t .$

  Thus,

  $ P\(upright("no cars during the call")\)= P\(Y = 0\)= e^(- 4 / 3 t) . $

  We require this probability to be at least 0.4:

  $ e^(- 4 / 3 t) gt.eq 0.4 arrow.l.r.double t lt.eq 0.6872 approx 41.2 upright(" seconds.") $

+ Wackerly 3.130 --- A parking lot has two entrances. Cars arrive at entrance I according to a Poisson distribution at an average of 3/hour and at entrance II according to a Poisson distribution at an average of 4/hour. What is the probability that a total of three cars will arrive at the parking lot in a given hour?

  Answer: We assume that the numbers of cars arriving at the two entrances are independent.

  Let $X =$ number of cars arriving at entrance I and $Y =$ number of cars arriving at entrance II. We have $X tilde.op "Poisson"\(3\)$ and $Y tilde.op "Poisson"\(4\)$.

  Because the two counts are independent, the total $T = X + Y$ is also Poisson, with parameter equal to the sum:

  $ T tilde.op "Poisson"\(3 + 4\)= "Poisson"\(7\). $

  We want exactly 3 cars:

  $ P\(T = 3\)= frac(7^3 e^(- 7), 3 !) approx 0.0521 . $

  The key property here is:

  $ X tilde.op "Pois"\(lambda_1\)\,#h(0em) Y tilde.op "Pois"\(lambda_2\)\,quad X perp Y #h(0em) arrow.r.double #h(0em) X + Y tilde.op "Pois"\(lambda_1 + lambda_2\). $

  This is the #strong[superposition] property of independent Poisson variables.

+ Wackerly 3.134 --- Consider a binomial experiment for $n = 20$, $p = 0.05$. Calculate the binomial probabilities for $Y = 0\,1\,2\,3 upright(" and ") 4$. Calculate the same probabilities by using the Poisson approximation with $lambda = n p$.

  Answer: Here, $Y tilde.op "Bin"\(n = 20\,p = 0.05\).$

  For the binomial distribution,

  $ P\(Y = y\)= binom(20, y)\(0.05\)^y\(0.95\)^(20 - y). $

  For the Poisson approximation, $lambda = n p = 20\(0.05\)= 1 arrow.l.r.double W tilde.op "Poisson"\(1\).$

  Then, $ P\(W = y\)= frac(e^(- 1), y !) . $

  #table(
    columns: 3,
    align: (center,right,right,),
    table.header([$y$], [Exact binomial], [Poisson approximation],),
    table.hline(),
    [0], [0.35849], [0.36788],
    [1], [0.37735], [0.36788],
    [2], [0.18868], [0.18394],
    [3], [0.05958], [0.06131],
    [4], [0.01333], [0.01533],
  )
  So the approximation is quite close for all these values. The reason is that $n = 20$ is reasonably large and $p = 0.05$ is small, while $n p = 1$.

  Therefore, $"Bin"\(20\,0.05\)approx "Pois"\(1\)$ works fairly here.

+ Wackerly 3.138 --- Let $Y$ have a Poisson distribution with mean $lambda$. Show that $V\(Y\)= lambda$.

  Answer: We have $ P\(Y = y\)= frac(lambda^y e^(- lambda), y !)\,#h(2em) y = 0\,1\,2\,dots.h . $

  We already know $E\(Y\)= lambda .$

  We have $ E\[Y\(Y - 1\)\]= sum_(y = 0)^oo y\(y - 1\)frac(lambda^y e^(- lambda), y !) . $

  The terms for $y = 0$ and $y = 1$ are zero, so $ E\[Y\(Y - 1\)\]= sum_(y = 2)^oo y\(y - 1\)frac(lambda^y e^(- lambda), y !) . $

  Now we use \$y! = y(y-1)(y-2)!,

  so $ frac(y\(y - 1\), y !) = frac(1, \(y - 2\)!) $.

  Therefore, $ E\[Y\(Y - 1\)\]= e^(- lambda) sum_(y = 2)^oo frac(lambda^y, \(y - 2\)!) . $

  If we factor out $lambda^2$: $ E\[Y\(Y - 1\)\]= lambda^2 e^(- lambda) sum_(y = 2)^oo frac(lambda^(y - 2), \(y - 2\)!) . $

  Set $k = y - 2$. Then $ E\[Y\(Y - 1\)\]= lambda^2 e^(- lambda) sum_(k = 0)^oo frac(lambda^k, \(k\)!) . $

  But, see #ref(<sec-exponential-series>, supplement: [Section]),

  $ sum_(k = 0)^oo frac(lambda^k, \(k\)!) = e^lambda . $

  Hence, $ E\[Y\(Y - 1\)\]= lambda^2 . $

  Now we use $Y^2 = Y\(Y - 1\)+ Y$.

  Taking expectations, $E\(Y^2\)= E\[Y\(Y - 1\)\]+ E\(Y\).$

  Thus, $E\(Y^2\)= lambda^2 + lambda .$

  Finally, $ V\(Y\)= E\(Y^2\)-\[E\(Y\)\]^2=\(lambda^2 + lambda\)- lambda^2 = lambda . $

  Therefore, for a Poisson rv, $E\(Y\)= V\(Y\)= lambda$.

+ Wackerly 3.142 --- Let $p\(y\)$ denote the probability function associated with a Poisson rv with mean $lambda$.

  #block[
  #set enum(numbering: "a.", start: 1)
  + Show that the ratio of successive probabilities satisfies $frac(p\(y\), p\(y - 1\)) = lambda / y$, for $y = 1\,2\,dots.h .$

    Answer: We divide both probabilities:

    $ frac(p\(y\), p\(y - 1\)) & = frac(lambda^y e^(- lambda), y !) / frac(lambda^(y - 1) e^(- lambda), \(y - 1\)!)\
     & = frac(lambda^y e^(- lambda), y !) frac(\(y - 1\)!, lambda^(y - 1) e^(- lambda))\
     & = lambda / y . $

  + For which values of $y$ is $p\(y\)> p\(y - 1\)$?

    Answer: $p\(y\)> p\(y - 1\)$ exactly when $ frac(p\(y\), p\(y - 1\)) > 1 . $ Thus, $lambda / y > 1 .$ So, $y < lambda$.

    Therefore, $ p\(y\)> p\(y - 1\)upright(" when ") y < lambda . $

    So the Poisson probabilities increase while $y < lambda$ and decrease once $y > lambda$.

  + Show that $p\(y\)$ is maximized when $y =$ the greatest integer less than or equal to $lambda$.

    Answer: From $frac(p\(y\), p\(y - 1\)) = lambda / y$, we can directly compare two successive Poisson probabilities.

    If $y < lambda$, then $lambda / y > 1$, so $p\(y\)> p\(y - 1\)$.

    If $y > lambda$, then $lambda / y < 1$, so $p\(y\)< p\(y - 1\)$.

    Therefore the probabilities increase while $y < lambda$, then decrease once $y > lambda$.

    Hence the maximum occurs around $lambda$, specifically at

    $ y = floor.l lambda floor.r . $

    Why? Suppose $lambda$ is not an integer.

    Let $m = floor.l lambda floor.r .$ By definition of the floor, $m < lambda < m + 1$. Therefore,

    $ frac(p\(m\), p\(m - 1\)) = lambda / m > 1\, $

    so $p\(m\)> p\(m - 1\)$.

    But for the next integer,

    $ frac(p\(m + 1\), p\(m\)) = frac(lambda, m + 1) < 1\, $

    so $p\(m + 1\)< p\(m\)$.

    Thus $p\(m\)$ is where the probabilities stop increasing and start decreasing. Hence

    $ "mode"\(Y\)= floor.l lambda floor.r . $

    If $lambda$ is an integer, say $lambda = m$, then

    $ frac(p\(m\), p\(m - 1\)) = m / m = 1 . $

    Hence $ p\(m\)= p\(m - 1\). $

    Before that point the probabilities are increasing, and after it they are decreasing, so these two equal probabilities are both maximal:

    $ "modes"\(Y\)= lambda - 1 upright(" and ") lambda . $
  ]

==== Moments and moment-generating functions
<moments-and-moment-generating-functions>
The parameters $mu$ and $sigma$ are meaningful numerical descriptive measures that locate the center and describe the spread associated with the values of a rv $Y$. They do not, however, provide a unique characterization of the distribution of $Y$. Many different distributions possess the same means and standard deviations.

The $k$th #strong[moment] of a random variable $Y$ #strong[taken about the origin] is defined to be $E (Y^k)$ and is denoted by $mu'_k$.

Notice in particular that the first moment about the origin is $E\(Y\)= mu'_1 = mu$ and $mu'_2 = E\(Y^2\)$ is employed for finding $sigma^2$.

The $k$th #strong[moment] of a random variable #strong[taken about its mean], or the $k$th central moment of $Y$, is defined to be $E\[\(Y - mu\)^k\]$ and is denoted by $mu_k$.

In particular, $sigma^2 = mu_2$.

The #strong[moment-generating function] $m\(t\)$ for a random variable $Y$ is defined to be $m\(t\)= E\(e^(t Y)\).$ We say that a moment-generating function for $Y$ exists if there exists a positive constant $b$ such that $m\(t\)$ is finite for $\|t\|lt.eq b$, to make sure the MGF exists in a neighborhood of 0 so we can differentiate it there.

Additional explanation
Why is $E\(e^(t Y)\)$ called the moment-generating function for $Y$?

From the series expansion for $e^(t y)$, we have

$ e^(t y) = 1 + t y + frac(\(t y\)^2, 2 !) + frac(\(t y\)^3, 3 !) + dots.h . $

For a discrete rv, $E\[g\(Y\)\]= sum_y g\(y\)p\(y\).$

Then, assuming that $mu'_k$ is finite for $k = 1\,2\,3\,dots.h\,$ we have

$ E\(e^(t Y)\) & = sum_y e^(t y) p\(y\)\
 & = sum_y [1 + t y + frac(\(t y\)^2, 2 !) + frac(\(t y\)^3, 3 !) + dots.h.c] p\(y\)\
 & = sum_y p\(y\)+ t sum_y y p\(y\)+ frac(t^2, 2 !) sum_y y^2 p\(y\)+ frac(t^3, 3 !) sum_y y^3 p\(y\)+ dots.h.c\
 & = 1 + t mu'_1 + frac(t^2, 2 !) mu'_2 + frac(t^3, 3 !) mu'_3 + dots.h.c . $

Thus, $E\(e^(t Y)\)$ is a function of all the moments $mu'_k$ about the origin, for $k = 1\,2\,3\,dots.h .$ In particular, $mu'_k$ is the coefficient of $t^k\/k !$ in the series expansion of $m\(t\)$.
If $m\(t\)$ exists, then for any positive integer $k$,

$ frac(d^k m\(t\), d t^k)\|_(t = 0) = m^(\(k\))\(0\)= mu'_k . $

In other words, if we find the $k$th derivative of $m\(t\)$ with respect to $t$ and then set $t = 0$, the result will be $mu'_k$.

Proof
$frac(d^k m\(t\), d t^k)$, or $m^(\(k\))\(t\)$, is the $k$th derivative of $m\(t\)$ with respect to $t$.

Because

$ m\(t\)= E\(e^(t Y)\)= 1 + t mu'_1 + frac(t^2, 2 !) mu'_2 + frac(t^3, 3 !) mu'_3 + dots.h.c\, $

it follows that

$ m^(\(1\))\(t\)= mu'_1 + frac(2 t, 2 !) mu'_2 + frac(3 t^2, 3 !) mu'_3 + dots.h.c\, $

$ m^(\(2\))\(t\)= mu'_2 + frac(2 t, 2 !) mu'_3 + frac(3 t^2, 3 !) mu'_4 + dots.h.c\, $

and, in general,

$ m^(\(k\))\(t\)= mu'_k + frac(2 t, 2 !) mu'_(k + 1) + frac(3 t^2, 3 !) mu'_(k + 2) + dots.h.c . $

Setting $t = 0$ in each of the above derivatives, we obtain

$ m^(\(1\))\(0\)= mu'_1\,#h(2em) m^(\(2\))\(0\)= mu'_2\, $

and, in general,

$ m^(\(k\))\(0\)= mu'_k . $
The primary application of a moment-generating function is to prove that a rv possesses a particular probability distribution $p\(y\)$. If $m\(t\)$ exists for a probability distribution $p\(y\)$, it is unique.

Also, if the moment-generating functions for two random variables $Y$ and $Z$ are equal, then $Y$ and $Z$ must have the same probability distribution.

If we can recognize the moment-generating function of a random variable $Y$ to be one associated with a specific distribution, then $Y$ must have that distribution.

In summary, the MGF sometimes but not always provides an easy way to find moments associated with random variables.

Some exercises
#heading(level: 1, numbering: none)[References]
<references>
#block[
] <refs>



#bibliography(("references.bib"))

