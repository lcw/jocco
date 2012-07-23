# __jocco__ is a Julia port of [Docco](http://jashkenas.github.com/docco/),
# the quick-and-dirty, hundred-line-long, literate-programming-style
# documentation generator. It produces HTML that displays your comments
# alongside your code. Comments are passed through
# [pandoc](http://johnmacfarlane.net/pandoc/), and code is
# syntax highlighted with [pygments](http://pygments.org/).
# This page is the result of running jocco against its own source file:
#
#     julia jocco.jl jocco.jl
#
# Using [pandoc](http://johnmacfarlane.net/pandoc/) allows us to have math
# inline $x=y$ or in display mode
# $$
#   \begin{aligned}
#     \nabla \times \vec{\mathbf{B}} -\, \frac1c\,
#     \frac{\partial\vec{\mathbf{E}}}{\partial t} &=
#     \frac{4\pi}{c}\vec{\mathbf{j}} \\
#     \nabla \cdot \vec{\mathbf{E}} &= 4 \pi \rho \\
#     \nabla \times \vec{\mathbf{E}}\, +\, \frac1c\,
#     \frac{\partial\vec{\mathbf{B}}}{\partial t} &= \vec{\mathbf{0}} \\
#     \nabla \cdot \vec{\mathbf{B}} &= 0
#   \end{aligned}
# $$
# if you wish.  This uses the [MathJax](http://www.mathjax.org/) Content
# Distribution Network script to turn $\LaTeX$ source into rendered output
# and thus an internet connection is required.
# [MathJax](http://www.mathjax.org/) may be installed locally if offline access
# is desired.
#
# @Knuth:1984:LP might be something we should read when building a literate
# programming tool.  We can also reference this in a note.[^1]
#
# Here is a julia code example:
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {.julia .numberLines}
# function foo(bar)
#     bar
# end
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#

const code_sep = "# CUT HERE\n"
const code_sep_html = "<span class=\"c\"># CUT HERE</span>\n"
const docs_sep = "\n##### CUT HERE\n\n"
const docs_sep_html = r"<h5 id=\"cut-here.*\">CUT HERE</h5>\n"

const header = "<!DOCTYPE html>

<html>
<head>
  <title>%title%</title>
  <meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\">
  <link rel=\"stylesheet\" media=\"all\" href=\"jocco.css\" />
  <script type=\"text/javascript\"
    src=\"http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML\">
  </script>
</head>
<body>
  <div id=\"container\">
    <div id=\"background\"></div>
    <table cellpadding=\"0\" cellspacing=\"0\">
      <thead>
        <tr>
          <th class=\"docs\">
            <h1>
              %title%
            </h1>
          </th>
          <th class=\"code\">
          </th>
        </tr>
      </thead>
      <tbody>
"

const table_entry = "
<tr id=\"section-%index%\">
<td class=\"docs\">
  <div class=\"pilwrap\">
    <a class=\"pilcrow\" href=\"#section-%index%\">&#182;</a>
  </div>
  %docs_html%
</td>
<td class=\"code\">
<div class=\"highlight\"><pre>%code_html%
</pre></div>
</td>
</tr>
"

const footer = "
      </tbody>
    </table>
  </div>
</body>
</html>"

function parse_source(source)
    code, docs = ASCIIString[], ASCIIString[]
    f = open(source)

    has_code = false
    code_text, docs_text = "", ""
    for line in readlines(f)
        line = chomp(line)
        m = match(r"^\s*(?:#\s(.*?)\s*$|$)", line)
        if m == nothing
            m = match(r"^\s*#()$", line)
        end
        if m == nothing || m.captures == (nothing,)
            has_code = true
            code_text = "$code_text$line\n"
        else
            if has_code
                code = push(code, code_text)
                docs = push(docs, docs_text)

                has_code = false
                code_text, docs_text = "", ""
            end
            (doc_line,) = m.captures
            docs_text = "$docs_text$doc_line\n"
        end
    end
    code = push(code, code_text)
    docs = push(docs, docs_text)

    close(f)
    code, docs
end

function highlight(text_array, sep_in, sep_out, cmd)
    write_stream = fdio(write_to(cmd).fd, true)
    read_stream = fdio(read_from(cmd).fd, true)

    spawn(cmd)

    write(write_stream, join(text_array, sep_in))
    close(write_stream)

    text_out = readall(read_stream)
    close(read_stream)

    wait(cmd)

    split(text_out, sep_out)
end

function highlight_code(code)
    cmd = `pygmentize -l julia -f html -O encoding=utf8`
    code = highlight(code, code_sep, code_sep_html, cmd)
    if length(code) > 0
        code[1] = replace(code[1], "<div class=\"highlight\"><pre>", "")
        code[length(code)] = replace(code[length(code)], "</pre></div>", "")
    end
    code
end

function get_files_with_extension(dir, wanted_ext)
    files = split(chomp(readall(`ls $dir`)), "\n")
    ext_files = Array(ASCIIString, 1, 0)
    for f in files
        filename = file_path(dir, f)
        pathname, filebase, ext = fileparts(filename)
        if(ext == wanted_ext)
            ext_files = [ext_files filename]
        end
    end
    ext_files
end

function join_arg_vals(arg, vals)
    args = Array(ASCIIString, 1, 2*length(vals))
    args[1:2:end] = arg
    args[2:2:end] = vals
    args
end

function highlight_docs(docs, path)
    bib_files = get_files_with_extension(path, ".bib")
    csl_files = get_files_with_extension(path, ".csl")
    pan_files = get_files_with_extension(path, ".hs")

    bib_args = join_arg_vals("--bibliography", bib_files)
    csl_args = join_arg_vals("--csl",          csl_files)

    pan_args = ["-S" bib_args csl_args "-f" "markdown" "-t" "json"]

    cmd = `pandoc $pan_args`
    for p in pan_files
        cmd = cmd | `runhaskell $p`
    end
    cmd  = cmd | `pandoc -S --mathjax -f json -t html`

    docs = highlight(docs, docs_sep, docs_sep_html, cmd)
end

function generate_html(source, path, file, code, docs, jump_to)
    outfile = file_path(path, replace(file, r"jl$", "html"))
    f = open(outfile, "w")

    h = replace(header, r"%title%", source)
    write(f, h)

    assert(length(code)==length(docs))
    for i = 1:length(code)
        t = replace(table_entry, r"%index%", i)
        t = replace(t, r"%docs_html%", docs[i])
        t = replace(t, r"%code_html%", code[i])
        write(f, t)
    end

    write(f, footer)

    close(f)
    println("$file --> $outfile")
end

# Here is some more documentation
# lets see if we can find it

function generate_documentation(source, path, file, jump_to)
    code, docs = parse_source(source)
    code, docs = highlight_code(code), highlight_docs(docs, path)
    generate_html(source, path, file, code, docs, jump_to)
end

function main()
    jump_to = ""

    for source in ARGS
        file = chomp(readall(`basename $source`))
        path = file_path(chomp(readall(`dirname  $source`)), "docs")

        # Ensure the docs directory exists
        run(`mkdir -p $path`)

        generate_documentation(source, path, file, jump_to)
    end
end

main()

# ## References
#
# [^1]: A citation without locators [@Knuth:1984:LP].
