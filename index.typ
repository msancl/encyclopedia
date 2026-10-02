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

== Derivatives
<sec-derivatives>
=== Basic rules
<basic-rules>
For constants $a$, $c$ and differentiable functions $f\(x\)$ and $g\(x\)$,

$ frac(d, d x)\[c\]= 0\, $

$ frac(d, d x)\[x^a\]= a x^(a - 1)\, $

$ frac(d, d x)\[c f\(x\)\]= c f'\(x\)\, $

$ frac(d, d x)\[f\(x\)+ g\(x\)\]= f'\(x\)+ g'\(x\)\, $

$ frac(d, d x)\[f\(x\)- g\(x\)\]= f'\(x\)- g'\(x\). $

=== Product rule
<product-rule>
$ frac(d, d x)\[f\(x\)g\(x\)\]= f'\(x\)g\(x\)+ f\(x\)g'\(x\). $

=== Quotient rule
<quotient-rule>
$ frac(d, d x) [frac(f\(x\), g\(x\))] = frac(f'\(x\)g\(x\)- f\(x\)g'\(x\), \[g\(x\)\]^2) . $

=== Chain rule
<chain-rule>
If

$ y = f\(g\(x\)\)\, $

then

$ frac(d y, d x) = f'\(g\(x\)\)g'\(x\). $

Equivalently,

$ frac(d, d x) f\(g\(x\)\)= f'\(g\(x\)\)g'\(x\). $

This is the rule used whenever a function appears #strong[inside another function].

Example
Consider

$ y =\(3 x + 2\)^5. $

This is a composition of two functions:

$ f\(x\)= 3 x + 2 $

and

$ g\(u\)= u^5 . $

Therefore,

$ y = g\(f\(x\)\). $

Using the chain rule,

$ frac(d y, d x) = g'\(f\(x\)\)f'\(x\). $

Since

$ g'\(u\)= 5 u^4 $

and

$ f'\(x\)= 3\, $

we obtain

$ frac(d y, d x) = 5\(3 x + 2\)^4dot.op 3 = 15\(3 x + 2\)^4. $
=== Powers of functions
<powers-of-functions>
$ frac(d, d x)\[f\(x\)\]^a= a\[f\(x\)\]^(a - 1)f'\(x\). $

In particular,

$ frac(d, d x) sqrt(f\(x\)) = frac(f'\(x\), 2 sqrt(f\(x\))) . $

and

$ frac(d, d x) frac(1, f\(x\)) = - frac(f'\(x\), \[f\(x\)\]^2) . $

=== Exponential functions
<exponential-functions>
$ frac(d, d x) e^x = e^x . $

More generally,

$ #box(stroke: black, inset: 3pt, [$ frac(d, d x) e^(f\(x\)) = e^(f\(x\)) f'\(x\) $]) $

by the chain rule.

For a constant $a > 0$,

$ frac(d, d x) a^x = a^x ln\(a\)\, $

and

$ frac(d, d x) a^(f\(x\)) = a^(f\(x\)) ln\(a\)thin f'\(x\). $

=== Logarithms
<logarithms>
$ frac(d, d x) ln x = 1 / x . $

More generally,

$ #box(stroke: black, inset: 3pt, [$ frac(d, d x) ln\[f\(x\)\]= frac(f'\(x\), f\(x\)) $]) $

provided $f\(x\)> 0$.

For logarithms with base $a$,

$ frac(d, d x) log_a x = frac(1, x ln\(a\))\, $

and

$ frac(d, d x) log_a\[f\(x\)\]= frac(f'\(x\), f\(x\)ln\(a\)) . $

=== Trigonometric functions
<trigonometric-functions>
$ frac(d, d x) sin x = cos x\, $

$ frac(d, d x) cos x = - sin x\, $

$ frac(d, d x) tan x = sec^2 x . $

With an inner function $f\(x\)$,

$ frac(d, d x) sin\[f\(x\)\]= cos\[f\(x\)\]f'\(x\)\, $

$ frac(d, d x) cos\[f\(x\)\]= - sin\[f\(x\)\]f'\(x\)\, $

$ frac(d, d x) tan\[f\(x\)\]= sec^2\[f\(x\)\]f'\(x\). $

Also,

$ frac(d, d x) sec x = sec x tan x\, $

$ frac(d, d x) csc x = - csc x cot x\, $

$ frac(d, d x) cot x = - csc^2 x . $

=== Inverse trigonometric functions
<inverse-trigonometric-functions>
$ frac(d, d x) arcsin x = 1 / sqrt(1 - x^2)\, $

$ frac(d, d x) arccos x = - 1 / sqrt(1 - x^2)\, $

$ frac(d, d x) arctan x = frac(1, 1 + x^2) . $

With an inner function $f\(x\)$,

$ frac(d, d x) arcsin\[f\(x\)\]= frac(f'\(x\), sqrt(1 -\[f\(x\)\]^2))\, $

$ frac(d, d x) arccos\[f\(x\)\]= - frac(f'\(x\), sqrt(1 -\[f\(x\)\]^2))\, $

$ frac(d, d x) arctan\[f\(x\)\]= frac(f'\(x\), 1 +\[f\(x\)\]^2) . $

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

  #block[
  #set enum(numbering: "a.", start: 1)
  + If $n$ = 5 and a missile enters the zone, what is the probability that exactly four sets detect the missile? At least one set?

    Answer: Let \$Y = \$number of radar sets that detect the missile. Since the radar sets operate independently and each detects the missile with probability $p = 0.9$, we have $Y tilde.op "Bin"\(n\,0.9\)$.

    For exactly four sets detecting the missile: $ P\(Y = 4\)= binom(5, 4)\(0.9\)^4\(0.1\)^1= 0.32805 . $

    For at least one set detecting the missile, it is easier to use the complement:

    $ P\(Y gt.eq 1\)= 1 - P\(Y = 0\)= 1 -\(0.1\)^5= 0.99999 . $

  + How large must be $n$ if we require that the probability of detecting a missile that enters the zone be 0.999?

    Answer: $ P\(Y\)gt.eq 0.999 arrow.l.r.double 1 -\(0.1\)^(n thin)gt.eq 0.999 arrow.l.r.double n gt.eq 3 . $

    Indeed, $ P\(upright("at least one detection")\)= 1 -\(0.1\)^3= 1 - 0.001 = 0.999 . $
  ]

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
+ Wackerly Example 3.23 --- Find the moment-generating function $m\(t\)$ for a Poisson distributed random variable with mean $lambda$.

  Answer: $ m\(t\) & = E\(e^(t Y)\)= sum_(y = 0)^oo e^(t y) p\(y\)= sum_(y = 0)^oo e^(t y) frac(lambda^y e^(- lambda), y !)\
   & = e^(- lambda) sum_(y = 0)^oo frac((lambda e^t)^y, y !) =_(upright("exponential series")) e^(- lambda) e^(lambda e^t) = e^(lambda\(e^t - 1\)) $ See #ref(<sec-exponential-series>, supplement: [Section]).

+ Wackerly Example 3.24 --- Use the MGF to find the mean and variance for the Poisson random variable.

  Answer: $mu = mu'_1 = m^(\(1\))\(0\)$ and $mu = mu'_2 = m^(\(2\))\(0\)$.

  Taking the first and second derivatives of $m\(t\)$, we obtain

  $ m^(\(1\))\(t\) & = frac(d, d t) [e^(lambda\(e^t - 1\))] = e^(lambda\(e^t - 1\)) dot.op lambda e^t\,\
  m^(\(2\))\(t\) & = frac(d, d t) [e^(lambda\(e^t - 1\)) dot.op lambda e^t] = e^(lambda\(e^t - 1\)) dot.op (lambda e^t)^2 + e^(lambda\(e^t - 1\)) dot.op lambda e^t . $

  Then,

  $ mu & = m^(\(1\))\(0\)= [e^(lambda\(e^t - 1\)) dot.op lambda e^t]_(t = 0) = lambda\,\
  mu'_2 & = m^(\(2\))\(0\)= [e^(lambda\(e^t - 1\)) dot.op \( lambda e^t \)^2 + e^(lambda\(e^t - 1\)) dot.op lambda e^t]_(t = 0) = lambda^2 + lambda . $

  To find $sigma^2$, we simply use the fact that

  $ sigma^2 = E\(Y^2\)- mu^2 = mu'_2 - mu^2 = lambda^2 + lambda -\(lambda\)^2= lambda . $

+ Wackerly Example 3.25 --- Suppose that $Y$ is a rv with mgf $m_Y\(t\)= e^(3.2\(e^t - 1\)) .$ What is the distribution of $Y$?

  Answer: We showed that the mgf of a Poisson distributed rv with mean $lambda$ is $m\(t\)= e^(lambda\(e^t - 1\))$. Because mgfs are unique, $Y$ must have a Poisson distribution with mean 3.2.

+ Wackerly 3.145 --- If $Y$ has a binomial distribution with $n$ trials and probability of success $p$, show that the mgf for $Y$ is

  $ m\(t\)= (p e^t + q)^n\,quad upright("where ") q = 1 - p . $

  Answer: we start from the definition of the mgf: $ m\(t\)= E\(e^(t Y)\)= sum_(y = 0)^n e^(t y) P\(Y = y\). $

  For $Y tilde.op "Bin"\(n\,p\)$,

  the probability distribution function is

  $ P\(Y = y\)= binom(n, y) p^y q^(n - y)\,#h(2em) q = 1 - p . $

  We then substitute it inside:

  $ m\(t\)= sum_(y = 0)^n e^(t y) binom(n, y) p^y q^(n - y) . $

  We can combine $e^(t y)$ and $p^y$:

  $ e^(t y) p^y =\(e^t\)^yp^y =\(p e^t\)^y. $

  Therefore, $ m\(t\)= sum_(y = 0)^n binom(n, y)\(p e^t\)^yq^(n - y) . $

  This has exactly the form of the binomial theorem:

  $ \(a + b\)^n= sum_(y = 0)^n binom(n, y) a^y b^(n - y) . $

  If we take $a = p e^t$ and $b = q$, we have

  $ m\(t\)=\(p e^t + q\)^n. $

+ Wackerly 3.153 --- Find the distributions of the random variables that have each of the following mgfs:

  #block[
  #set enum(numbering: "a.", start: 1)
  + $ m\(t\)= [\( 1 \/ 3 \) e^t + \( 2 \/ 3 \)]^5 . $

    Answer: The idea is to match each mgf with a known mgf form.

    We can identify $p = 1\/3$, $q = 2\/3$ and $n = 5$. Therefore, $Y tilde.op "Bin"\(5\,1\/3\).$

  + $ m\(t\)= frac(e^t, 2 - e^t) . $

    Answer: The geometric mgf is $ m\(t\)= frac(p e^t, 1 - q e^t) . $

    If we divide the numerator and the denominator by 2 in the expression, we get:

    $ frac(e^t, 2 - e^t) = frac(1 / 2 e^t, 1 - 1 / 2 e^t) . $

    Hence, $p = 1\/2$, $q = 1\/2$, and $Y tilde.op "Geom"\(1 / 2\)$, where $Y = 1\,2\,3\,dots.h$ is the trial on which the first success occurs.

  + $ m\(t\)= e^(2\(e^t - 1\)) . $

    Answer: The Poisson mgf is $ m\(t\)= e^(lambda\(e^t - 1\)) . $

    So $lambda = 2$ and $Y tilde.op "Pois"\(2\).$
  ]

+ Wackerly 3.155 --- Let $m\(t\)=\(1\/6\)e^t +\(2\/6\)e^(2 t) +\(3\/6\)e^(3 t)$.

  #block[
  #set enum(numbering: "a.", start: 1)
  + Find $E\(Y\)$.

    Answer:

    Differentiate the moment-generating function once:

    $ m'\(t\) & = 1 / 6 e^t + 2 / 6\(2 e^(2 t)\)+ 3 / 6\(3 e^(3 t)\)\
     & = 1 / 6 e^t + 4 / 6 e^(2 t) + 9 / 6 e^(3 t) . $

    Since

    $ E\(Y\)= m'\(0\)\, $

    we obtain

    $ E\(Y\) & = m'\(0\)\
     & = 1 / 6 + 4 / 6 + 9 / 6\
     & = 14 / 6\
     & = 7 / 3 . $

  + Find $V\(Y\)$.

    Answer:

    To find the variance, first compute the second derivative:

    $ m''\(t\) & = 1 / 6 e^t + 8 / 6 e^(2 t) + 27 / 6 e^(3 t) . $

    Since

    $ E\(Y^2\)= m''\(0\)\, $

    we obtain

    $ E\(Y^2\) & = m''\(0\)\
     & = 1 / 6 + 8 / 6 + 27 / 6\
     & = 36 / 6\
     & = 6 . $

    Then

    $ V\(Y\)= E\(Y^2\)-\[E\(Y\)\]^2. $

    Therefore,

    $ V\(Y\) & = 6 - (7 / 3)^2\
     & = 6 - 49 / 9\
     & = 54 / 9 - 49 / 9\
     & = 5 / 9 . $

  + Find the distribution of $Y$.

    Answer:

    For a discrete random variable,

    $ m\(t\)= E\(e^(t Y)\)= sum_y e^(t y) p\(y\). $

    Comparing this with

    $ m\(t\)= 1 / 6 e^t + 2 / 6 e^(2 t) + 3 / 6 e^(3 t)\, $

    we can read the probabilities directly:

    $ P\(Y = 1\)= 1 / 6\, $

    $ P\(Y = 2\)= 2 / 6 = 1 / 3\, $

    and

    $ P\(Y = 3\)= 3 / 6 = 1 / 2 . $

    Therefore,

    $ p\(y\)= cases(delim: "{", 1 / 6\, & y = 1\,, 1 / 3\, & y = 2\,, 1 / 2\, & y = 3\,, 0\, & upright("otherwise") .) $

    The probabilities sum to

    $ 1 / 6 + 2 / 6 + 3 / 6 = 1 . $
  ]

+ Wackerly 3.158 --- If $Y$ is a rv with mgf $m\(t\)$ and if $W$ is given by $W = a Y + b$, show that the mgf of $W$ is $e^(t b) m\(a t\)$.

  Answer: Start from the definition of the moment-generating function of $W$:

  $ m_W\(t\)= E\(e^(t W)\). $

  Since

  $ W = a Y + b\, $

  we have

  $ m_W\(t\) & = E (e^(t\(a Y + b\)))\
   & = E (e^(t a Y) e^(t b)) . $

  Because $e^(t b)$ does not depend on the random variable $Y$, it is constant with respect to the expectation:

  $ m_W\(t\) & = e^(t b) E (e^(t a Y)) . $

  Now, since

  $ m_Y\(t\)= E\(e^(t Y)\)\, $

  replacing $t$ by $a t$ gives

  $ m_Y\(a t\)= E (e^(\(a t\)Y)) = E (e^(t a Y)) . $

  Therefore,

  $ #box(stroke: black, inset: 3pt, [$ m_W\(t\)= e^(t b) m_Y\(a t\) $]) $

+ Wackerly 3.162 --- Let $r\(t\)= l n\[m\(t\)\]$ and $r^(\(k\))\(0\)$ denote the $k$th derivative of $r\(t\)$ evaluated for $t = 0$. Show that $r^(\(1\)) = 0 = mu'_1 = mu$ and $r^(\(2\))\(0\)= mu'_2 -\(mu'_1\)^2= sigma^2 .$

  Answer:

  Since

  $ r\(t\)= ln\[m\(t\)\]\, $

  using

  $ frac(d, d t) ln\[f\(t\)\]= frac(f'\(t\), f\(t\))\, $

  we obtain

  $ r'\(t\)= frac(m'\(t\), m\(t\)) . $

  Also,

  $ m\(0\)= E\(e^(0 Y)\)= E\(1\)= 1 . $

  Therefore,

  $ r'\(0\) & = frac(m'\(0\), m\(0\))\
   & = mu'_1 / 1\
   & = mu'_1\
   & = mu . $

  Hence,

  $ #box(stroke: black, inset: 3pt, [$ r'\(0\)= mu . $]) $

  For the second derivative we now differentiate

  $ r'\(t\)= frac(m'\(t\), m\(t\)) $

  using the quotient rule:

  $ frac(d, d t) [frac(f\(t\), g\(t\))] = frac(f'\(t\)g\(t\)- f\(t\)g'\(t\), \[g\(t\)\]^2) . $

  Therefore,

  $ r''\(t\)= frac(m''\(t\)m\(t\)-\[m'\(t\)\]^2, \[m\(t\)\]^2) . $

  Evaluating at $t = 0$,

  $ r''\(0\) & = frac(m''\(0\)m\(0\)-\[m'\(0\)\]^2, \[m\(0\)\]^2)\
   & = frac(mu'_2\(1\)-\(mu'_1\)^2, 1^2)\
   & = mu'_2 -\(mu'_1\)^2. $

  Since

  $ mu'_2 = E\(Y^2\) $

  and

  $ mu'_1 = E\(Y\)= mu\, $

  we obtain

  $ r''\(0\) & = E\(Y^2\)-\[E\(Y\)\]^2\
   & = V\(Y\)\
   & = sigma^2 . $

  Hence,

  $ #box(stroke: black, inset: 3pt, [$ r''\(0\)= sigma^2 . $]) $

+ Wackerly 3.163 --- Find the mean and variance of a Poisson rv with $m\(t\)= e^(5\(e^t - 1\))$ using the results of the previous exercise.

  Answer: Using the result from the previous exercise,

  $ r\(t\)= ln\[m\(t\)\]\, $

  with

  $ r'\(0\)= mu $

  and

  $ r''\(0\)= sigma^2 . $

  Here,

  $ m\(t\)= e^(5\(e^t - 1\)) . $

  Therefore,

  $ r\(t\) & = ln\[m\(t\)\]\
   & = ln (e^(5\(e^t - 1\)))\
   & = 5\(e^t - 1\). $

  Differentiate once:

  $ r'\(t\)= 5 e^t . $

  Hence,

  $ mu & = r'\(0\)\
   & = 5 e^0\
   & = 5 . $

  Therefore,

  $ #box(stroke: black, inset: 3pt, [$ mu = 5 . $]) $

  For the variance, differentiate again:

  $ r''\(t\)= 5 e^t . $

  Therefore,

  $ sigma^2 & = r''\(0\)\
   & = 5 e^0\
   & = 5 . $

  Hence,

  $ #box(stroke: black, inset: 3pt, [$ sigma^2 = 5 . $]) $

==== Probability-generating functions
<probability-generating-functions>
An important class of discrete random variables is one in which $Y$ represents a count and consequently takes integer values: $Y = 0\,1\,2\,3\,dots.h .$ The binomial, geometric, hypergeometric, and Poisson random variables all fall in this class.

A mathematical device useful in finding the probability distribution and other properties of integer-valued random variables is the probability-generating function.

Let $Y$ be an integer-valued rv for which $P\(Y = i\)= p_i$, where $i = 0\,1\,2\,dots.h .$ The #strong[probability-generating function] $P\(t\)$ for $Y$ is defined to be $ P\(t\)= E\(t^y\)= p_0 + p_1 t + p_2 t^2 + dots.h = sum_(i = 0)^oo p_i t^i $ for all values of $t$ such that $P\(t\)$ is finite.

The reason for calling $P\(t\)$ a probability-generating function is clear when we compare $P\(t\)$ with the mgf $m\(t\)$. In particular, the coefficient of $t^i$ in $P\(t\)$ is the probability $p_i$. Correspondingly, the coefficient of $t^i$ for $m\(t\)$ is a constant times the $i$th moment $mu'_i$. If we know $P\(t\)$ and can expand it into a series, we can determine $p\(y\)$ as the coefficient of $t^y$.

Repeated differentiation of $P\(t\)$ yields #strong[factorial moments] for the random variable $Y$.

The $k$th factorial moment for a random variable $Y$ is defined to be

$ mu_(\[k\]) = E\[Y\(Y - 1\)\(Y - 2\)dots.h\(Y - k + 1\)\]\, $ where $k$ is a positive integer.

Notice that $mu_(\[1\]) = E\(Y\)= mu .$ The second factorial moment, $mu_(\[2\]) = E\[Y\(Y - 1\)\]$, useful in finding the variance.

If \$P(t) is the probability-generating function for an integer-valued random variable, $Y$, then the $k$th factorial moment of $Y$ is given by $ frac(d^k P\(t\), d t^k)\|_(t = 1) = P^(\(k\))\(1\)= mu_(\[k\]) . $

Proof
Because

$ P\(t\)= p_0 + p_1 t + p_2 t^2 + p_3 t^3 + p_4 t^4 + dots.h.c\, $

it follows that

$ P^(\(1\))\(t\)= frac(d P\(t\), d t) = p_1 + 2 p_2 t + 3 p_3 t^2 + 4 p_4 t^3 + dots.h.c\, $

$ P^(\(2\))\(t\)= frac(d^2 P\(t\), d t^2) =\(2\)\(1\)p_2 +\(3\)\(2\)p_3 t +\(4\)\(3\)p_4 t^2 + dots.h.c\, $

and, in general,

$ P^(\(k\))\(t\)= frac(d^k P\(t\), d t^k) = sum_(y = k)^oo y\(y - 1\)\(y - 2\)dots.h.c\(y - k + 1\)p\(y\)t^(y - k) . $

Setting $t = 1$ in each of these derivatives, we obtain

$ P^(\(1\))\(1\)= p_1 + 2 p_2 + 3 p_3 + 4 p_4 + dots.h.c = mu_(\[1\]) = E\(Y\)\, $

$ P^(\(2\))\(1\)=\(2\)\(1\)p_2 +\(3\)\(2\)p_3 +\(4\)\(3\)p_4 + dots.h.c = mu_(\[2\]) = E\[Y\(Y - 1\)\]\, $

and, in general,

$ P^(\(k\))\(1\) & = sum_(y = k)^oo y\(y - 1\)\(y - 2\)dots.h.c\(y - k + 1\)p\(y\)\
 & = E [Y \( Y - 1 \) \( Y - 2 \) dots.h.c \( Y - k + 1 \)]\
 & = mu_(\[k\]) . $

Some exercises
+ Wackerly Example 3.26 --- Find the probability-generating function for a geometric random variable.

  Answer: Notice that $p_0 = 0$ because $Y$ cannot take the value $0$. Therefore,

  $ P\(t\) & = E\(t^Y\)\
   & = sum_(y = 1)^oo t^y q^(y - 1) p\
   & = sum_(y = 1)^oo p / q\(q t\)^y\
   & = p / q [q t + \( q t \)^2 + \( q t \)^3 + dots.h.c] . $

  The terms form an infinite geometric series. For $q t < 1$,

  $ q t +\(q t\)^2+\(q t\)^3+ dots.h.c = frac(q t, 1 - q t) . $

  Therefore,

  $ P\(t\) & = p / q (frac(q t, 1 - q t))\
   & = frac(p t, 1 - q t)\,#h(2em) t < 1 / q . $

+ Wackerly Example 3.27 --- Use $P\(t\)$ to find the mean of a geometric random variable.

  Answer: We know that $ mu_(\[1\]) = mu = P^(\(1\))\(1\). $

  Using the result from Example 3.26,

  $ P\(t\)= frac(p t, 1 - q t) . $

  Differentiate using the quotient rule:

  $ P^(\(1\))\(t\) & = frac(d, d t) (frac(p t, 1 - q t))\
   & = frac(\(1 - q t\)p -\(p t\)\(- q\), \(1 - q t\)^2) . $

  Setting $t = 1$,

  $ P^(\(1\))\(1\) & = frac(\(1 - q\)p + p q, \(1 - q\)^2)\
   & = frac(p^2 + p q, p^2)\
   & = frac(p\(p + q\), p^2)\
   & = 1 / p\, $

  since

  $ p + q = 1 . $

  Therefore,

  $ #box(stroke: black, inset: 3pt, [$ E\(Y\)= mu = 1 / p . $]) $

+ Wackerly 3.165 --- Let $Y$ denote a Poisson rv with mean $lambda$. Find the probability-generating function for $Y$ and use it to find $E\(Y\)$ and $V\(Y\)$.

  Answer: Let

  $ Y tilde.op "Pois"\(lambda\)\, $

  so that

  $ P\(Y = y\)= frac(lambda^y e^(- lambda), y !)\,#h(2em) y = 0\,1\,2\,dots.h $

  The probability-generating function is

  $ P\(t\)= E\(t^Y\). $

  Since $Y$ is discrete,

  $ P\(t\)= sum_(y = 0)^oo t^y P\(Y = y\). $

  Therefore,

  $ P\(t\) & = sum_(y = 0)^oo t^y frac(lambda^y e^(- lambda), y !)\
   & = e^(- lambda) sum_(y = 0)^oo frac(\(lambda t\)^y, y !)\
   & = e^(- lambda) e^(lambda t)\
   & = e^(lambda\(t - 1\)) . $

  Thus,

  $ #box(stroke: black, inset: 3pt, [$ P\(t\)= e^(lambda\(t - 1\)) . $]) $

  To find the mean, use

  $ E\(Y\)= P'\(1\). $

  Differentiate:

  $ P'\(t\)= lambda e^(lambda\(t - 1\)) . $

  Therefore,

  $ E\(Y\) & = P'\(1\)\
   & = lambda e^(lambda\(1 - 1\))\
   & = lambda . $

  Hence,

  $ #box(stroke: black, inset: 3pt, [$ E\(Y\)= lambda . $]) $

  For the variance, the second derivative gives the second factorial moment:

  $ P''\(1\)= E\[Y\(Y - 1\)\]. $

  Differentiate again:

  $ P''\(t\)= lambda^2 e^(lambda\(t - 1\)) . $

  Therefore,

  $ P''\(1\)= lambda^2\, $

  so

  $ E\[Y\(Y - 1\)\]= lambda^2 . $

  Since

  $ Y^2 = Y\(Y - 1\)+ Y\, $

  we obtain

  $ E\(Y^2\) & = E\[Y\(Y - 1\)\]+ E\(Y\)\
   & = lambda^2 + lambda . $

  Finally,

  $ V\(Y\) & = E\(Y^2\)-\[E\(Y\)\]^2\
   & = lambda^2 + lambda - lambda^2\
   & = lambda . $

  Therefore,

  $ #box(stroke: black, inset: 3pt, [$ E\(Y\)= lambda\,#h(2em) V\(Y\)= lambda . $]) $

+ Wackerly 3.166 --- Use the probability-generating function found in the previous exercise to find $E\(Y^3\)$.

  Answer: From the previous exercise, the probability-generating function of a Poisson random variable is

  $ P\(t\)= e^(lambda\(t - 1\)) . $

  We want to find

  $ E\(Y^3\). $

  The derivatives of the probability-generating function give factorial moments:

  $ P'\(1\)= E\(Y\)\, $

  $ P''\(1\)= E\[Y\(Y - 1\)\]\, $

  and

  $ P'''\(1\)= E\[Y\(Y - 1\)\(Y - 2\)\]. $

  Differentiate the probability-generating function:

  $ P'\(t\)= lambda e^(lambda\(t - 1\))\, $

  $ P''\(t\)= lambda^2 e^(lambda\(t - 1\))\, $

  and

  $ P'''\(t\)= lambda^3 e^(lambda\(t - 1\)) . $

  Setting $t = 1$,

  $ P'\(1\)= lambda\, $

  $ P''\(1\)= lambda^2\, $

  and

  $ P'''\(1\)= lambda^3 . $

  Therefore,

  $ E\(Y\)= lambda\, $

  $ E\[Y\(Y - 1\)\]= lambda^2\, $

  and

  $ E\[Y\(Y - 1\)\(Y - 2\)\]= lambda^3 . $

  We now rewrite $Y^3$ in terms of factorial expressions. First,

  $ Y\(Y - 1\)\(Y - 2\) & = Y\(Y^2 - 3 Y + 2\)\
   & = Y^3 - 3 Y^2 + 2 Y . $

  Also,

  $ Y\(Y - 1\)= Y^2 - Y\, $

  so

  $ Y^2 = Y\(Y - 1\)+ Y . $

  Substituting this into the previous expression,

  $ Y\(Y - 1\)\(Y - 2\) & = Y^3 - 3\[Y\(Y - 1\)+ Y\]+ 2 Y\
   & = Y^3 - 3 Y\(Y - 1\)- Y . $

  Therefore,

  $ Y^3 = Y\(Y - 1\)\(Y - 2\)+ 3 Y\(Y - 1\)+ Y . $

  Taking expectations,

  $ E\(Y^3\)= E\[Y\(Y - 1\)\(Y - 2\)\]+ 3 E\[Y\(Y - 1\)\]+ E\(Y\). $

  Using the factorial moments found above,

  $ E\(Y^3\) & = lambda^3 + 3 lambda^2 + lambda . $

  Therefore,

  $ #box(stroke: black, inset: 3pt, [$ E\(Y^3\)= lambda^3 + 3 lambda^2 + lambda . $]) $

==== Tchebysheff's theorem
<tchebysheffs-theorem>
The following result, known as #strong[Tchebysheff's theorem], can be used to determine a lower bound for the probability that the random variable $Y$ of interest falls in an interval $mu plus.minus k sigma$.

Let $Y$ be a random variable with mean $mu$ and finite variance $sigma^2$. Then, for any constant $k > 0$,

$ P\(\|Y - mu\|< k sigma\)gt.eq 1 - 1 / k^2 quad upright("or") quad P\(\|Y - mu\|gt.eq k sigma\)lt.eq 1 / k^2 . $

Two important aspects of this result should be pointed out. First, the result applies for any probability distribution. Second, the results of the theorem are very conservative in the sense that the actual probability that $Y$ is in the interval $mu plus.minus k sigma$ usually exceeds the lower bound for the probability, $1 - 1\/k^2$, by a considerable amount.

Some exercises
+ Wackerly Example 3.28 --- The number of customers per day at a sales counter, $Y$, has been observed for a long period of time and found to have mean 20 and standard deviation 2. The probability distribution of $Y$ is not known. What can be said about the probability that, tomorrow, $Y$ will be greater than 16 but less than 24?

  Answer: We want

  $ P\(16 < Y < 24\). $

  By Tchebysheff's theorem,

  $ P\(mu - k sigma < Y < mu + k sigma\)gt.eq 1 - 1 / k^2 . $

  Here,

  $ mu = 20\,#h(2em) sigma = 2 . $

  Since

  $ 20 - 2\(2\)= 16 #h(2em) upright("and") #h(2em) 20 + 2\(2\)= 24\, $

  we have $k = 2$. Therefore,

  $ P\(16 < Y < 24\) & = P\(mu - 2 sigma < Y < mu + 2 sigma\)\
   & gt.eq 1 - 1 / 2^2\
   & = 3 / 4 . $

  Thus,

  $ #box(stroke: black, inset: 3pt, [$ P\(16 < Y < 24\)gt.eq 3 / 4 . $]) $

  If instead $sigma = 1$, then $k = 4$, so

  $ P\(16 < Y < 24\)gt.eq 1 - 1 / 4^2 = 15 / 16 . $

+ Wackerly 3.167 --- Let $Y$ be a random variable with mean 11 and variance 9. Using Tchebysheff's theorem, find

  #block[
  #set enum(numbering: "a.", start: 1)
  + a lower bound for $P\(6 < Y < 16\)$

    Answer: We have

    $ mu = 11\,#h(2em) sigma = sqrt(9) = 3 . $

    The interval $\(6\,16\)$ is centered at the mean:

    $ 11 - k\(3\)= 6 #h(2em) arrow.r.double #h(2em) k = 5 / 3 . $

    By Tchebysheff's theorem,

    $ P\(6 < Y < 16\) & = P (mu - 5 / 3 sigma < Y < mu + 5 / 3 sigma)\
     & gt.eq 1 - frac(1, \(5\/3\)^2)\
     & = 1 - 9 / 25\
     & = 16 / 25 . $

    Therefore,

    $ #box(stroke: black, inset: 3pt, [$ P\(6 < Y < 16\)gt.eq 16 / 25 = 0.64 . $]) $

  + the value of $C$ such that $P\(\|Y - 11\|gt.eq C\)lt.eq 0.09 .$

    Answer: Tchebysheff's theorem gives

    $ P\(\|Y - mu\|gt.eq k sigma\)lt.eq 1 / k^2 . $

    We want

    $ P\(\|Y - 11\|gt.eq C\)lt.eq 0.09 . $

    Thus,

    $ 1 / k^2 = 0.09\, $

    so

    $ k^2 & = 1 / 0.09 = 100 / 9\,\
    k & = 10 / 3 . $

    Since

    $ C = k sigma $

    and $sigma = 3$,

    $ C = 10 / 3\(3\)= 10 . $

    Therefore,

    $ #box(stroke: black, inset: 3pt, [$ C = 10 . $]) $
  ]

+ Wackerly 3.171 --- For a certain type of soil the number of wireworms per cubic foot has a mean of 100. Assuming a Poisson distribution of wireworms, give an interval that will include at least 5/9 of the sample values of wireworms counts obtained from a large number of 1-cubic-foot samples.

  Answer: Since $Y$ has a Poisson distribution with mean $100$,

  $ mu = 100\,#h(2em) sigma^2 = 100\,#h(2em) sigma = 10 . $

  By Tchebysheff's theorem,

  $ P\(mu - k sigma < Y < mu + k sigma\)gt.eq 1 - 1 / k^2 . $

  We want the probability to be at least $5\/9$, so

  $ 1 - 1 / k^2 & = 5 / 9\
  1 / k^2 & = 4 / 9\
  k & = 3 / 2 . $

  Therefore,

  $ mu - k sigma & = 100 - 3 / 2\(10\)= 85\,\
  mu + k sigma & = 100 + 3 / 2\(10\)= 115 . $

  Thus, an interval containing at least $5\/9$ of the sample values is

  $ #box(stroke: black, inset: 3pt, [$ \(85\,115\). $]) $

+ Wackerly 3.179 --- We determined that the mean and variance of the costs necessary to find three employees with positive indications of asbestos poisoning were 150 and 4500, respectively. Is it highly unlikely that the cost of completing the tests will exceed \$$350$?

  Answer: We are given

  $ mu = 150\,#h(2em) sigma^2 = 4500\,#h(2em) sigma = sqrt(4500) approx 67.08 . $

  We want to bound

  $ P\(Y > 350\). $

  Since $350$ is $200$ above the mean,

  $ 350 - 150 = 200 . $

  Thus,

  $ P\(Y > 350\)lt.eq P\(\|Y - 150\|gt.eq 200\). $

  Write $200$ in terms of standard deviations:

  $ k = 200 / 67.08 approx 2.98 . $

  By Tchebysheff's theorem,

  $ P\(\|Y - 150\|gt.eq 200\) & lt.eq frac(1, \(2.98\)^2)\
   & approx 0.113 . $

  Therefore,

  $ #box(stroke: black, inset: 3pt, [$ P\(Y > 350\)lt.eq 0.113 . $]) $

  Tchebysheff's theorem only guarantees that the probability is at most about $11.3 %$, so we cannot conclude that exceeding $\$350$ is highly unlikely.

==== Summary
<summary>
This chapter covered discrete random variables, their probability mass functions, expected values, and the main discrete distributions: binomial, geometric, negative binomial, hypergeometric, and Poisson.

#table(
  columns: (27.27%, 36.36%, 36.36%),
  align: (auto,right,right,),
  table.header([Distribution], [$E\(Y\)$], [$V\(Y\)$],),
  table.hline(),
  [Binomial], [$n p$], [$n p q$],
  [Geometric], [$1 / p$], [$q / p^2$],
  [Hypergeometric], [$n r / N$], [$n r / N frac(N - r, N) frac(N - n, N - 1)$],
  [Poisson], [$lambda$], [$lambda$],
  [Negative binomial], [$r / p$], [$frac(r q, p^2)$],
)
The corresponding R functions are:

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Distribution], [$P\(Y = y_0\)$], [$P\(Y lt.eq y_0\)$],),
  table.hline(),
  [Binomial], [#NormalTok("dbinom(y0, n, p)");], [#NormalTok("pbinom(y0, n, p)");],
  [Geometric], [#NormalTok("dgeom(y0 - 1, p)");], [#NormalTok("pgeom(y0 - 1, p)");],
  [Hypergeometric], [#NormalTok("dhyper(y0, r, N-r, n)");], [#NormalTok("phyper(y0, r, N-r, n)");],
  [Poisson], [#NormalTok("dpois(y0, lambda)");], [#NormalTok("ppois(y0, lambda)");],
  [Negative binomial], [#NormalTok("dnbinom(y0 - r, r, p)");], [#NormalTok("pnbinom(y0 - r, r, p)");],
)
Moment-generating functions can be used to obtain moments and identify distributions, while probability-generating functions are useful for moments and distributions of integer-valued random variables.

Finally, Tchebysheff's theorem provides probability bounds when only the mean and variance are known.

Supplementary exercises
+ Wackerly 3.202 --- The number of cars driving past a parking area in a one-minute time interval has a Poisson distribution with mean $lambda$. The probability that any individual driver actually wants to park his or her car is $p$. Assume that individuals decide whether to park independently of one another.

  #block[
  #set enum(numbering: "a.", start: 1)
  + If one parking place is available and it will take you one minute to reach the parking area, what is the probability that a space will still be available when you reach the lot. Assume that no one leaves the lot during the one-minute interval.

    Answer: Let $Y$ be the number of cars that pass the parking area during the minute. Then

    $ Y tilde.op "Pois"\(lambda\). $

    If exactly $Y = y$ cars pass, each driver independently does #strong[not] want to park with probability $1 - p$. Therefore,

    $ P\(upright("space available") divides Y = y\)=\(1 - p\)^y. $

    To obtain the unconditional probability, sum over all possible values of $Y$:

    $ P\(upright("space available")\) & = sum_(y = 0)^oo\(1 - p\)^yP\(Y = y\)\
     & = sum_(y = 0)^oo\(1 - p\)^yfrac(lambda^y e^(- lambda), y !)\
     & = e^(- lambda) sum_(y = 0)^oo frac(\[lambda\(1 - p\)\]^y, y !) . $

    Using the exponential series,

    $ sum_(y = 0)^oo frac(x^y, y !) = e^x\, $

    we obtain

    $ P\(upright("space available")\) & = e^(- lambda) e^(lambda\(1 - p\))\
     & = e^(- lambda p) . $

    Therefore,

    $ #box(stroke: black, inset: 3pt, [$ P\(upright("space still available")\)= e^(- lambda p) . $]) $

  + Let $W$ denote the number of drivers who wish to park during a one-minute interval. Derive the probability distribution of $W$.

    Answer: Let $Y$ be the total number of cars passing during the minute, with

    $ Y tilde.op "Pois"\(lambda\)\, $

    and let $W$ be the number of those drivers who wish to park.

    Conditional on $Y = y$, each of the $y$ drivers independently wishes to park with probability $p$. Therefore,

    $ W divides Y = y tilde.op "Bin"\(y\,p\). $

    For $w = 0\,1\,2\,dots.h$,

    $ P\(W = w\)= sum_(y = w)^oo P\(W = w divides Y = y\)P\(Y = y\). $

    Substituting the binomial and Poisson probabilities,

    $ P\(W = w\) & = sum_(y = w)^oo binom(y, w) p^w\(1 - p\)^(y - w)frac(lambda^y e^(- lambda), y !)\
     & = e^(- lambda) frac(\(lambda p\)^w, w !) sum_(y = w)^oo frac(\[lambda\(1 - p\)\]^(y - w), \(y - w\)!) . $

    Letting $j = y - w$,

    $ P\(W = w\) & = e^(- lambda) frac(\(lambda p\)^w, w !) sum_(j = 0)^oo frac(\[lambda\(1 - p\)\]^j, j !)\
     & = e^(- lambda) frac(\(lambda p\)^w, w !) e^(lambda\(1 - p\))\
     & = frac(\(lambda p\)^we^(- lambda p), w !) . $

    This is the probability mass function of a Poisson random variable with mean $lambda p$. Therefore,

    $ #box(stroke: black, inset: 3pt, [$ W tilde.op "Pois"\(lambda p\). $]) $

    Thus, independently retaining each event of a Poisson count with probability $p$ produces another Poisson count with mean multiplied by $p$.

    This result is an example of #strong[Poisson thinning]. If events occur according to a Poisson distribution with mean $lambda$, and each event is independently retained with probability $p$, then the number of retained events is also Poisson, with mean

    $ lambda p . $

    Here, the original events are the cars passing the parking area, while the retained events are the drivers who actually wish to park. Therefore,

    $ W tilde.op "Pois"\(lambda p\). $
  ]

+ Wackerly 3.206 --- Accident records collected by an automobile insurance company give the following information. The probability that an insured driver has an automobile accident is 0.15. If an accident has occurred, the damage to the vehicle amounts to 20% of its market value with a probability of 0.80, to 60% of its market value with a probability of 0.12, and to a total loss with a probability of 0.08. What premium should the company charge on a \$12,000 car so that the expected gain by the company is zero?

  Answer: Let $L$ denote the insurer's loss on the car.

  An accident occurs with probability

  $ P\(upright("accident")\)= 0.15 . $

  Given that an accident occurs, the expected proportion of the car's value that is lost is

  $ E\(upright("damage proportion") divides upright("accident")\) & =\(0.20\)\(0.80\)+\(0.60\)\(0.12\)+\(1.00\)\(0.08\)\
   & = 0.16 + 0.072 + 0.08\
   & = 0.312 . $

  For a car worth $\$12\,000$, the expected loss conditional on an accident is therefore

  $ 12\,000\(0.312\)= 3\,744 . $

  Since an accident occurs only with probability $0.15$,

  $ E\(L\) & = 0.15\(3\,744\)\
   & = 561.60 . $

  If the premium is $P$, the insurer's expected gain is

  $ E\(upright("gain")\)= P - E\(L\). $

  For the expected gain to equal zero,

  $ P = E\(L\). $

  Therefore,

  $ #box(stroke: black, inset: 3pt, [$ P =\$561.60 . $]) $

+ Wackerly 3.211 --- A merchant stocks a certain perishable item. She knows that on any given day she will have a demand for either two, three, or four of these items with probabilities 0.1, 0.4, and 0.5, respectively. She buys the items for \$1.00 each and sells them for \$1.20 each. If any are left at the end of the day, they represent a total loss. How many items should the merchant stock in order to maximize her expected daily profit?

  Answer: Let $D$ denote daily demand:

  $ P\(D = 2\)= 0.1\,#h(2em) P\(D = 3\)= 0.4\,#h(2em) P\(D = 4\)= 0.5 . $

  Each item costs $\$1.00$ and sells for $\$1.20$. Unsold items have no value.

  If $s$ items are stocked, the profit is

  $ Pi = 1.20 min\(D\,s\)- s . $

  Because demand is always between $2$ and $4$, we compare stocking $2$, $3$, or $4$ items.

  If $s = 2$, both items are always sold:

  $ E\(Pi divides s = 2\)= 2\(1.20\)- 2 = 0.40 . $

  If $s = 3$,

  $ E\(Pi divides s = 3\) & = 0.1\[2\(1.20\)- 3\]+ 0.4\[3\(1.20\)- 3\]+ 0.5\[3\(1.20\)- 3\]\
   & = 0.1\(- 0.60\)+ 0.4\(0.60\)+ 0.5\(0.60\)\
   & = 0.48 . $

  If $s = 4$,

  $ E\(Pi divides s = 4\) & = 0.1\[2\(1.20\)- 4\]+ 0.4\[3\(1.20\)- 4\]+ 0.5\[4\(1.20\)- 4\]\
   & = 0.1\(- 1.60\)+ 0.4\(- 0.40\)+ 0.5\(0.80\)\
   & = 0.08 . $

  Thus,

  $ s = 2 & : quad E\(Pi\)=\$0.40\,\
  s = 3 & : quad E\(Pi\)=\$0.48\,\
  s = 4 & : quad E\(Pi\)=\$0.08 . $

  The expected profit is largest when three items are stocked. Therefore,

  $ #box(stroke: black, inset: 3pt, [$ upright("The merchant should stock ") 3 upright(" items.") $]) $

+ Wackerly 3.214 --- For simplicity, let us assume that there are two kinds of drivers. The safe drivers, who are 70% of the population, have probability 0.1 of causing an accident in a year. The rest of the population are accident makers, who have probability 0.5 of causing an accident in a year. The insurance premium is \$400 times one's probability of causing an accident in the following year. A new subscriber has an accident during the first year. What should be his insurance premium for the next year?

  Answer: Let

  $ S = upright("safe driver")\,#h(2em) A = upright("accident-maker")\, $

  and let $C$ denote the event that the driver causes an accident.

  Initially,

  $ P\(S\)= 0.70\,#h(2em) P\(A\)= 0.30\, $

  with

  $ P\(C divides S\)= 0.10\,#h(2em) P\(C divides A\)= 0.50 . $

  The subscriber caused an accident during the first year, so we first update the probabilities of the two driver types using Bayes' rule.

  The total probability of an accident is

  $ P\(C\) & = P\(C divides S\)P\(S\)+ P\(C divides A\)P\(A\)\
   & =\(0.10\)\(0.70\)+\(0.50\)\(0.30\)\
   & = 0.22 . $

  Therefore,

  $ P\(S divides C\) & = frac(P\(C divides S\)P\(S\), P\(C\))\
   & = frac(\(0.10\)\(0.70\), 0.22)\
   & = 7 / 22\, $

  and

  $ P\(A divides C\)= 15 / 22 . $

  The probability of an accident in the following year is obtained using the #strong[law of total probability].

  After observing an accident in the first year,

  $ P\(S divides C\)= 7 / 22\,#h(2em) P\(A divides C\)= 15 / 22 . $

  Since the subscriber must be either a safe driver or an accident-maker,

  $ P\(upright("accident next year") divides C\) & = P\(upright("accident next year") divides S\)P\(S divides C\)\
   & quad + P\(upright("accident next year") divides A\)P\(A divides C\)\
   & =\(0.10\)7 / 22 +\(0.50\)15 / 22\
   & = 41 / 110\
   & approx 0.3727 . $

  Thus, the next-year accident probability is a weighted average of the accident probabilities for the two driver types, using the #strong[updated probabilities] of belonging to each type after the first-year accident.

  The premium is $\$400$ times this probability:

  $ upright("Premium") & = 400 (41 / 110)\
   & approx 149.09 . $

  Therefore,

  $ #box(stroke: black, inset: 3pt, [$ upright("Premium") approx\$149.09 . $]) $

  The accident increases the estimated probability that the subscriber is an accident-maker, so the premium is based on the updated accident probability rather than the original population average.

=== Continuous variables
<continuous-variables>
A random variable that can take on any value in an interval is called #strong[continuous].

The probability distribution for a discrete random variable can always be given by assigning a nonnegative probability to each of the possible values the variable may assume. In every case, of course, the sum of all the probabilities that we assign must be equal to 1. Unfortunately, the probability distribution for a continuous random variable cannot be specified in the same way. It is mathematically impossible to assign nonzero probabilities to all the points on a line interval while satisfying the requirement that the probabilities of the distinct possible values sum to 1. As a result, we must develop a different method to describe the probability distribution for a continuous random variable.

#heading(level: 1, numbering: none)[References]
<references>
#block[
] <refs>



#bibliography(("references.bib"))

