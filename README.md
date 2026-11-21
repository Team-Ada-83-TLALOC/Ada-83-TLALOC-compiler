# TLALOC - Ada 83 Compiler

```
                            |
                         \\ | //
                       \\ u ^ u //                 /-------_______------\
                     \ )Y|Y|Y|Y|Y( /               |  T  h e            |
                       / /o o o\ \                 |  L  o n e s o m e  |
                      \|H|H|H|H|H|/                |  A  d a            |
                     G))  Q   Q  ((G               |  L  o v i n g      |
                      / \   "   / \                |  O  l't i m e r's  |
                     /_/  \V¨V/  \_\               |  C  o m p i l e r  |
                         \vvvvv/                   \-------______-------/
                       \ooooooooo/
```

**Preserving the legacy of Ada 83 (MIL-STD-1815A-1983)**

---

## Why Ada 83 Matters

Ada 83 powered some of the most critical systems in computing history:

- **Aerospace**: Ariane 5 launcher, space missions
- **Aviation**: Boeing 777 flight control systems
- **Defense**: Military embedded systems worldwide
- **Industrial**: Real-time control systems

TLALOC is an experimental compiler whose aim is preserving this heritage by implementing the full Ada 83 standard using modern development tools.

---

## Intended Features

- **Full Ada 83 Compliance**: Implements MIL-STD-1815A-1983 standard
- **DIANA 86 Representation**: Descriptive Intermediate Attributed Notation for Ada
- **Self Hosted**: Compiles and builts itself
- **Modern Bootstrap Toolchain**: Built with GNAT 13.3.0, generates text FASM assembly
- **Separate Compilation**: Full library management with `.DCL`, `.BDY`, `.SUB` files
- **Debug-Friendly**: Multiple well separated compilation phases with inspection options
- **Portable Stack Machine Backend**: LLIR (Low Level Intermediate Representation) with code generation for x86-64/Linux, AArch64/Linux, risc-V64/Linux.

---

## Architecture

```
Source Code (.ada)
        ↓
   [PAR_PHASE]  ──→  Lexical & Syntax Analysis
        ↓
   [LIB_PHASE]  ──→  Library & Dependencies
        ↓
   [SEM_PHASE]  ──→  Semantic Analysis (65% of compiler)
        ↓
   [EXPANDER]   ──→  LLIR/FASM Generation  ─────────────→  TARGET_CODE or FASM (fasmg)
        ↓                                                     ↓      
   [WRITE_LIB]  ──→  Library Output (.DCL/.BDY/.SUB)          ELF 64 Executable
```

### Key Components

| Module | Lines | Role |
|--------|-------|------|
| **SEM_PHASE** | 22,193 | Semantic analysis (28 subunits) |
| **EXPANDER** | 5,971 | Code generation to FASM LLIR stack machine |
| **PAR_PHASE** | 1,924 | Lexical and syntactic analysis |
| **LIB_PHASE** | 1,230 | Library and dependency management |
| **IDL** | 2,123 | DIANA graph management |

---

## Quick Start

### Prerequisites

- **Linux on x86** (Ubuntu 24.04 or compatible)
- **GNAT** 13.3+ (Ada compiler for building TLALOC)
- **FASM** (Flat Assembler - g.kd3c or compatible)

### Installation

```bash
# Clone the repository
git clone https://github.com/Team-Ada-83-TLALOC/Ada-83-TLALOC-compiler.git
cd Ada-83-TLALOC-compiler
# make a build directory if not already present
mkdir ./build
# Recompile the compiler with gnat / fasmg to obtain T1.exe (gnat made TLALOC)
./make_T1
# Recompile the compiler with T1 to obtain TLALOC.x86exe (TLALOC made TLALOC)
cd ./bin
./comp_TLALOC
```

### First Program Use

Go to **bin** directory
```bash
# Compile and create a .FINC macro text in ./ADA__LIB with command :

./TLALOC COMPILE dis_bonjour.adb

# Create a .fas macro header file in ./ADA__LIB also.

./TLALOC BIND DIS_BONJOUR

# create an ELF64 executable file in ADA__LIB.

./TLALOC CODE DIS_BONJOUR

# Launch DIS_BONJOUR executable

./ADA__LIB/DIS_BONJOUR.x86exe

# The program displays **" Bonjour "**.

# Hope it works on your computer...
```

## Compilation verbs and qualifiers

TLALOC uses a DCL like CLI :

<pre>
TLALOC HELP [verb]
TLALOC COMPILE [/PROJECT=dir] [/STOP_PHASE[=SYNTAX|LIB|SEMANTICS|EXPAND|WRITELIB]] source
TLALOC BIND    [/PROJECT=dir] unit
TLALOC CODE    [/PROJECT=dir] [/TARGET=X86_64|ARM64|RISCV64] [/MAP] unit

TLALOC DUMP    [/PROJECT=dir] [/FORMAT[=PRETTY/UGLY|ALLTREE]]
</pre>

/PROJECT_DIR has default "./" .
The /STOP_PHASE default is WRITELIB which kills the DIANA $$$.TMP work file, DUMP then cannot operate. To dump a DIANA tree, stop must be no later than EXPAND phase.
/TARGET defaults at X86_64

### Example: Debugging Semantic Analysis

Stop after semantic phase and inspect DIANA tree
```bash
# Compile with stop after sem phase
./TLALOC COMPILE /STOP_PHASE=SEMANTICS my_program.ada /PROJECT=my_project

# Dump DIANA tree in $$$_TREE.TXT
./TLALOC DUMP  /FORMAT=ALLTREE  my_program.ada /PROJECT=my_project
```

---

## DIANA: The Heart of TLALOC

**DIANA** (Descriptive Intermediate Attributed Notation for Ada) is a standardized graph-based intermediate representation for Ada programs.

- **Nodes**: Represent language constructs (declarations, expressions, statements)
- **Attributes**: Semantic information attached to nodes
- **Graph Structure**: Captures program structure and dependencies
- **Storage**: Binary format in `ADA__LIB/$$$.TMP` during compilation

DIANA enables:
- Clear separation of compiler phases
- Easy debugging with `PRETTY_DIANA` tool
- Standardized intermediate format for Ada tools

---

## Project Structure

```
Ada83_TLALOC/
├── src/
│   ├── ada_comp/          # Main compiler driver
│   ├── cli/               # CLI parsing and command definition
│   ├── par_phase/         # Parsing (LEX, GRMR_OPS, GRMR_TBL)
│   ├── sem_phase/         # Semantic analysis (28 subunits!)
│   ├── expander/          # LLIR generation
│   ├── pretty/            # DIANA pretty-printer
│   ├── target_code/      # Code generation (X86, arm, riscv
│   └── communs/           # Shared utilities (IDL management)
├── bin/
│   └── idl_tools/         # DIANA node definitions
└── projects/              # Example Ada 83 programs
```

---

## Technical Details

### Target Platform
- **OS**: Linux (Ubuntu 24.04+)
- **Processors**: x86-64, arm AArch64, RISC-V64
- **Assembler**: fasmg (Flat Assembler) or TLALOC.TARGET_CODE
- **Output**: ELF 64 Linux executables
- **tested SBC**:

   Orange Pi 3B with armbian

   Starfive Visionfive 2 with Debian


### Compilation Statistics
- **Total code**: 34,344 lines
- **Number of files**: 85
- **Largest module**: SEM_PHASE (64.6% of codebase)
- **Frontend/Backend ratio**: 4.8:1 (typical for research compilers)

### Ada 83 Specifics
- Full separate compilation model
- Generic units and instantiation
- Tasking (concurrent programming)
- Representation clauses
- ❌ No Ada 95+ features (no child packages, protected types, etc.)

---

## Documentation

- **[Ada 83 Memory Wiki](https://ada83.org/wiki/)**: Language reference and tutorials
- **[Project Documentation](docs/)**: Compiler internals and architecture
- **[MIL-STD-1815A-1983](https://ada83.org/)**: Official Ada 83 standard (~270 pages)

### Key Documents
- `structure_TLALOC_compiler.md`: Module-by-module breakdown
- `RESUME_ANALYSE_TLALOC.txt`: Statistical analysis and metrics
- `doc_mise_en_place.md`: Project organization and setup

---

## Contributing

TLALOC is a heritage preservation project. Contributions are welcome!

### Areas for Contribution
- **Testing**: Ada 83 validation suite
- **Documentation**: User guides, tutorials
- **Bug fixes**: Compiler issues
- **Features**: Optimization passes, better diagnostics
- **Education**: Teaching materials for compiler construction

**Note**: TLALOC targets Ada 83 only. Please do not submit features from later Ada standards (Ada 95, 2005, 2012, 2022).

---

## Educational Value

TLALOC serves as an excellent resource for:
- **Compiler Construction**: Clear phase separation, well-documented passes
- **Programming Language Theory**: Ada's type system, generics, tasking
- **Software Archaeology**: Understanding 1980s compiler technology
- **Formal Methods**: Ada's design-by-contract philosophy

### Code Quality
- **Modular Design**: 99 well-organized files
- **Clear Responsibilities**: Each subunit has a focused purpose
- **Extensive Comments**: Comprehensive inline documentation
- **Research-Grade**: Academic-quality implementation

---

## Related Resources

- **[Ada 83 Official Site](https://ada83.org/)**: Language resources and community
- **[Framagit Mirror](https://framagit.org/VMo/ada-83-compiler-tools)**: Alternative repository
- **[Ada Information Clearinghouse](http://www.adaic.org/)**: Historical Ada information
- **[Ada 83 LRM](https://ada83.org/wiki/)**: Language Reference Manual

---

## Historical Context

Ada 83 was developed by the U.S. Department of Defense in the early 1980s to address the "software crisis" in embedded systems. Named after Augusta Ada Lovelace, the world's first programmer, Ada introduced revolutionary concepts:

- **Strong Typing**: Catch errors at compile-time
- **Generics**: Reusable, type-safe templates
- **Tasking**: Built-in concurrent programming
- **Packages**: Modular program organization
- **Exceptions**: Structured error handling

TLALOC preserves this heritage by providing a working implementation of the original 1983 standard.

---

## Project Status

**Current State**: Functional experimental bootstrapped compiler self hosted (compiles itself to executable).

- Parsing and lexical analysis complete
- Semantic analysis fully implemented
- LLIR code generation to FASM working
- Library management operational
- Auto compilation of all system ok (gnat not necessary anymore)
- Ongoing: Bug fixes and validation
- Ongoing: Documentation improvements

---

## 🙏 Acknowledgments

- **Vincent Morin**: Project maintainer and primary developer
- **Jelle Hermsen**: Ada 83 Memory website collaboration
- **Ada Community**: For keeping the Ada legacy alive
- **Historical Compilers**: DEC Ada, Verdix Ada, Alsys Adaworld, Ada/Ed, Ada-minus - inspirations for this work
- **Current Compiler**: GNAT with -gnat83 flag

---

## Contact & Community

- **Website**: [https://ada83.org](https://ada83.org)

Repository
- **GitHub**: [https://https://github.com/Team-Ada-83-TLALOC/Ada-83-TLALOC-compiler](https://https://github.com/Team-Ada-83-TLALOC/Ada-83-TLALOC-compiler)

Historical repository (heavy)
- **Framagit**: [https://framagit.org/VMo/ada-83-compiler-tools](https://framagit.org/VMo/ada-83-compiler-tools)



---

## License


TLALOC/Ada 83 uses SPDX license identifiers in its maintained source files.

The compiler sources and runtime are licensed under GPL-3.0-or-later, with the
GCC Runtime Library Exception 3.1 where applicable.

The development repository may contain archival, experimental, or research
material that is not part of the official distribution. Official release archives
are intended to contain only files with explicit licensing information.

See directory [LICENSES](LICENSES) and files for details.

---


**TLALOC** - *The Lonesome Ada Loving Ol'timer Compiler*

*Preserving 1980s software engineering excellence for future generations*

**[Explore the Code](https://git.sr.ht/~vincent_morin/Ada_83_TLALOC)** • **[Read the Docs](https://ada83.org/wiki/)** • **[Try Examples](examples/)**

---

Made with ❤️ for Ada and software heritage preservation

---
