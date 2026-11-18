# Document Renamer

Parse PDF documents from the `~/Downloads/doc_renamer/` folder, rename them with human-readable filenames, and organize them into the `~/Downloads/doc_renamer/output/` folder. Supports three document types: **NF-e** (Notas Fiscais Eletrônicas), **Comprovantes Bancários** (bank payment receipts), and **Acertos de Frigoríficos** (slaughterhouse settlement reports).

The input folder is `~/Downloads/doc_renamer/`, outside this project. Process only the PDFs at its top level. Do not process the files in its subfolders (`output/`, `failed/`, `originals/`).

The output folder is `~/Downloads/doc_renamer/output/`, also outside this project. Always write to this full path. Never write to an `output/` folder in this project.

## How to Parse
Use the `Read` tool directly on the PDF files — Claude can read and extract text from PDFs natively. No external libraries or scripts needed.

## General Workflow

1. Read each PDF from `~/Downloads/doc_renamer/`
2. Detect the document type (NF-e, Comprovante Bancário, or Acerto de Frigorífico)
3. Extract the relevant fields
4. Copy the file to the appropriate `~/Downloads/doc_renamer/output/` subfolder with the new filename
5. Move the original file from `~/Downloads/doc_renamer/` to `processed/YYYY-MM-DD/` (using today's date)
6. **ALWAYS verify**: after every copy/move, run `ls` on the output folder and confirm the filename is exactly what was intended (no missing characters, correct value, correct beneficiary). Never skip this — even for a single file.

## Shell Gotchas

- Filenames contain `$` (e.g. `R$1.135,00.pdf`). In bash, **always use single quotes** for these paths, otherwise `$1`, `$2`, etc. get expanded by the shell and silently disappear from the filename. Use `'R$1.135,00.pdf'`, never `"R$1.135,00.pdf"`.

## Name Casing

All company and person names in filenames should use **Title Case**, except for well-known abbreviations which stay uppercase: LTDA, SA, S.A., S/A, ME, EPP, EIRELI, CNPJ, CPF.

Examples:
- `AJEL MATERIAIS ELETRICOS LTDA` → `Ajel Materiais Eletricos LTDA`
- `AGRO AMAZONIA SA` → `Agro Amazonia SA`
- `SEBASTIAO GIACHETO FERREIRA JUNIOR` → `Sebastiao Giacheto Ferreira Junior`

---

## Document Type Detection

- **NF-e**: Contains fields like "NOTA FISCAL ELETRÔNICA", "Série", "Nº.", "CHAVE DE ACESSO", "V. TOTAL DA NOTA"
- **NFS-e**: Contains "NOTA FISCAL DE SERVIÇOS ELETRÔNICA - NFS-e", "PRESTADOR DE SERVIÇOS", "TOMADOR DE SERVIÇOS" (service invoice, e.g. WebISS)
- **Comprovante Bancário**: Contains fields like "comprovante", "beneficiário", bank names, transfer/payment terminology
- **Acerto de Frigorífico**: Contains terms like "Acerto de Compra de Gado", "Romaneio de Abate", "Resumo de Abate", "Ordem Compra" combined with "Data Abate", "BOVINO", slaughterhouse branding (Minerva Foods, JBS, Friboi)

---

## NF-e (Nota Fiscal Eletrônica)

### Output Paths
- `~/Downloads/doc_renamer/output/NFe/<filename>.pdf` — Human-readable name
- `~/Downloads/doc_renamer/output/NFe/by_key/<chave_de_acesso>.pdf` — Named by access key (Chave de Acesso)

### Filename Format
```
YYYYMMDD - Issuer - Series NFNumber - R$Value.pdf
```

### Field Rules

| Field         | Source                    | Transformation                                                                                                                                                                                       |
| ------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Date**      | DATA DA EMISSÃO           | Format as `YYYYMMDD`                                                                                                                                                                                 |
| **Issuer**    | IDENTIFICAÇÃO DO EMITENTE | Shortened company name. Remove legal suffixes (LTDA, S.A., S/A, ME, EPP, EIRELI) and descriptive terms (PRODUTOS AGROPECUARIOS, DISTRIBUIDORA DE INSUMOS AGRICOLAS, EXPORT E IMPORT, COMERCIO, etc.) |
| **Series**    | Série                     | As-is                                                                                                                                                                                                |
| **NF Number** | Nº.                       | Remove leading zeros                                                                                                                                                                                 |
| **Value**     | V. TOTAL DA NOTA          | Prefix with `R$`, keep Brazilian formatting (dots for thousands, comma for decimals)                                                                                                                 |

### Examples
```
~/Downloads/doc_renamer/output/NFe/20260130 - Agro Amazonia - 1 22400 - R$11.497,80.pdf
~/Downloads/doc_renamer/output/NFe/20251110 - Agrocat - 10 36255 - R$25.200,00.pdf
~/Downloads/doc_renamer/output/NFe/20260202 - Amaggi - 0 186743 - R$7.530,91.pdf
```

---

## NFS-e (Nota Fiscal de Serviços Eletrônica)

Service invoices (e.g. WebISS / Município de Cacoal). Detected by "NOTA FISCAL DE SERVIÇOS ELETRÔNICA - NFS-e", "PRESTADOR DE SERVIÇOS" / "TOMADOR DE SERVIÇOS" sections.

### Output Paths
- `~/Downloads/doc_renamer/output/NFSe/<filename>.pdf` — Human-readable name
- `~/Downloads/doc_renamer/output/NFSe/by_key/<chave_de_acesso>.pdf` — Named by "Chave de Acesso da NFS-e Nacional" (from OUTRAS INFORMAÇÕES)

### Filename Format
```
YYYYMMDD - Prestador - NFNumber - R$Value.pdf
```
(Same as NF-e, but NFS-e has no Série.)

### Field Rules

| Field         | Source                       | Transformation                                                                                              |
| ------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Date**      | Emissão (Horário de Brasília) | Format as `YYYYMMDD`                                                                                        |
| **Prestador** | PRESTADOR DE SERVIÇOS        | Prefer the recognizable name (Nome Fantasia when the Razão Social is uninformative), shortened + Title Case |
| **NF Number** | "Nota:" box (top-right)      | Sequential part only, leading zeros removed (e.g. `202600 / 0007577` → `7577`)                              |
| **Value**     | Valor Total (R$)             | Prefix with `R$`, Brazilian formatting                                                                       |

### Duplicates
Files with the same Chave de Acesso are the same document: copy to `by_key/` only once; in `~/Downloads/doc_renamer/output/NFSe/` apply the normal `_1` collision suffix.

### Examples
```
~/Downloads/doc_renamer/output/NFSe/20260522 - Hospital dos Acidentados - 7577 - R$240,00.pdf
~/Downloads/doc_renamer/output/NFSe/20260430 - Lacus Med - 52 - R$3.077,00.pdf
```

---

## Comprovante Bancário (Bank Payment Receipt)

### Output Path
- `~/Downloads/doc_renamer/output/Comprovantes/<Bank>/<filename>.pdf` — Organized by source bank

### Filename Format
```
YYYYMMDD - Beneficiário - R$Value.pdf
```

### Field Rules

| Field            | Source                     | Transformation                                                                                           |
| ---------------- | -------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Bank**         | Source institution (payer) | Used for folder organization (e.g., "Banco da Amazônia", "Bradesco", "Nubank")                           |
| **Date**         | DATA DA EMISSÃO            | Format as `YYYYMMDD`                                                                                     |
| **Beneficiário** | IDENTIFICAÇÃO DO RECEBEDOR | Company or Person Name                                                                                   |
| **Value**        | V. TOTAL DO DCTO           | Prefix with `R$`, keep Brazilian formatting (dots for thousands, comma for decimals)                     |

### Examples
```
~/Downloads/doc_renamer/output/Comprovantes/Banco da Amazônia/20260130 - Agro Amazonia SA - R$11.497,80.pdf
~/Downloads/doc_renamer/output/Comprovantes/Bradesco/20251110 - Agrocat Distribuidora de Insumos LTDA - R$25.200,00.pdf
~/Downloads/doc_renamer/output/Comprovantes/Nubank/20260202 - Amaggi Exportacao e Importacao de Insumos - R$7.530,91.pdf
```

Note: Names should follow Title Case rules (see [Name Casing](#name-casing) section above).
```

### Final Destination (Dropbox)

After staging files in `~/Downloads/doc_renamer/output/Comprovantes/<Bank>/`, the canonical home for comprovantes is the user's Dropbox at:

```
/Users/sebastorama/Giacheto Agropec Dropbox/Sebastião Ferreira/Work - Rondonia/Conta Corrente/
```

#### Bank → Dropbox Folder Mapping

| Source Bank (payer) | Dropbox Folder                   |
| ------------------- | -------------------------------- |
| Banco da Amazônia   | `Comprovantes Banco da Amazonia` |
| Banco do Brasil     | `Comprovantes Banco do Brasil`   |
| Bradesco            | `Comprovantes Bradesco`          |
| Nubank              | `Comprovantes Nubank`            |
| Sicredi             | `Comprovantes Sicredi`           |

Note: the "Amazonia" folder has no accent — match the existing folder name exactly.

#### Confirmation Step (REQUIRED)

Before moving any comprovante to its Dropbox folder:

1. Stage all processed comprovantes in `~/Downloads/doc_renamer/output/Comprovantes/<Bank>/` first.
2. Present the user with a list grouped by destination folder, showing each filename and the target Dropbox path.
3. **Wait for explicit user confirmation** (e.g., "yes", "go", "proceed") before moving anything to Dropbox. The user may approve all at once or per file/per bank — follow what they say.
4. After confirmation, **move** each file from `~/Downloads/doc_renamer/output/Comprovantes/<Bank>/` to its Dropbox folder. Check for filename collisions in the destination — if a file with the same name already exists, follow the duplicate-suffix rule (`_1`, `_2`, ...).
5. After every move, run `ls` on the Dropbox destination to verify the file landed with the exact intended filename.

The original move from `~/Downloads/doc_renamer/` to `processed/YYYY-MM-DD/` still happens after the local stage in `~/Downloads/doc_renamer/output/`, independent of the Dropbox confirmation step.

---

## Acerto de Frigorífico (Slaughterhouse Settlement Report)

### Output Path
- `~/Downloads/doc_renamer/output/Acertos Frigoríficos/<filename>.pdf`

### Filename Format
```
YYYYMMDD - Frigorífico - XXX cb - XX.XXX,XX kg - XXX,XX kg⁄cb - R$X.XXX.XXX,XX - R$XX,XX⁄kg.pdf
```

Note: Use `⁄` (fraction slash U+2044) instead of `/` in filenames since `/` is not valid in filenames.

### Field Rules

| Field            | Source                                      | Transformation                                                                                     |
| ---------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| **Date**         | Data Abate / Data do Abate                  | Format as `YYYYMMDD`                                                                               |
| **Frigorífico**  | Document branding / emitter identification  | Map to known names (see Frigorífico Identification below)                                          |
| **Cabeças (cb)** | Total quantity of animals                   | Integer number followed by `cb`                                                                    |
| **Peso Total**   | Total weight in kg                          | Brazilian formatting (dots for thousands, comma for decimals) followed by `kg`                     |
| **Peso/cb**      | Calculated: Peso Total ÷ Cabeças           | Rounded to 2 decimal places, followed by `kg⁄cb`                                                  |
| **Value**        | Total líquido (after Funrural/SENAR)        | Prefix with `R$`, Brazilian formatting                                                             |
| **R$/kg**        | Calculated: Value ÷ Peso Total             | Rounded to 2 decimal places, prefixed with `R$`, followed by `⁄kg`                                |

### Frigorífico Identification

Map the document source to one of these known frigoríficos:

| Identifier in PDF                                    | Frigorífico Name       |
| ---------------------------------------------------- | ---------------------- |
| "Minerva Foods", "FORTUNCERES", Chupinguaia          | Minerva Chupinguaia    |
| "JBS", "Friboi", São Miguel do Guaporé               | JBS São Miguel         |
| "JBS", "Friboi", Vilhena                             | JBS Vilhena            |

If the document does not match any known frigorífico, **ask the user** for the correct name, suggesting the most likely option based on the document content (company name, city, etc.).

### Field Extraction by Frigorífico

#### Minerva (Minerva Foods / FORTUNCERES)
- **Date**: "Data Abate" field (e.g., "Data Abate - 06/03/2026")
- **Cabeças**: Sum of "TOTAL Animais" → "Cabeça" column across all "Ordem Compra" lotes, or from QUANTIDADE in the NF-e
- **Peso Total**: Sum of "TOTAL Animais" → "Peso" column across all lotes, or PESO BRUTO from the NF-e
- **Value (líquido)**: "Total Geral" from the "Acertos no Pagamento" section (after SENAR deductions)

#### JBS (JBS SA / Friboi)
- **Date**: "Data" field in the Acerto de Compra de Gado header (e.g., "Data: 06/03/2026")
- **Cabeças**: "Total Qtde" field
- **Peso Total**: "Peso Líquido" field
- **Value (líquido)**: "Total do Documento" field (after Funrural deduction)

### Examples
```
~/Downloads/doc_renamer/output/Acertos Frigoríficos/20260306 - Minerva Chupinguaia - 306 cb - 102.276,70 kg - 334,24 kg⁄cb - R$2.143.064,00 - R$20,95⁄kg.pdf
~/Downloads/doc_renamer/output/Acertos Frigoríficos/20260306 - JBS São Miguel - 90 cb - 24.885,00 kg - 276,50 kg⁄cb - R$524.976,63 - R$21,10⁄kg.pdf
```

---

## Handling Duplicate Output Filenames

When multiple documents produce the same output filename (same date, beneficiário/issuer, and value), append `_1`, `_2`, etc. to subsequent files:

```
20260218 - Alfa Sist de Gestao LTDA - R$1.219,54.pdf
20260218 - Alfa Sist de Gestao LTDA - R$1.219,54_1.pdf
20260218 - Alfa Sist de Gestao LTDA - R$1.219,54_2.pdf
```

The first file keeps the original name. Only add the suffix when there is an actual collision in the same output folder.

---

## Post-Processing: Move Originals to `processed/`

After a file has been successfully renamed and copied to `~/Downloads/doc_renamer/output/`, move the original from `~/Downloads/doc_renamer/` to:

```
processed/YYYY-MM-DD/
```

Where `YYYY-MM-DD` is **today's date** (the date of processing, not the document date).

### Handling Duplicate Filenames

Files in `processed/` may have duplicate names (e.g., multiple files named `Comprovante.pdf`). Handle this by appending an incrementing suffix before the extension:

```
Comprovante.pdf       → processed/2026-02-08/Comprovante.pdf
Comprovante.pdf       → processed/2026-02-08/Comprovante (1).pdf
Comprovante.pdf       → processed/2026-02-08/Comprovante (2).pdf
NFe_another.pdf       → processed/2026-02-08/NFe_another.pdf
```

Only add the suffix when there is an actual name collision.
