# ICAO 9303 MRZ Specification Reference

## Machine Readable Zone (MRZ)

### Format for TD1 (ID Cards - 3 lines)

```
Line 1 (30 characters):
IDVNM123456789<<<<<<<<<<<<<<<<

Line 2 (30 characters):
9001015M3012315VNM<<<<<<<<<<<5

Line 3 (30 characters):
NGUYEN<<VAN<A<<<<<<<<<<<<<<<<<<
```

### Field Breakdown

#### Line 1
```
Position  Length  Content
1-2       2       Document code (ID)
3-5       3       Issuing state (VNM)
6-14      9       Document number
15        1       Check digit (document number)
16-30     15      Optional data
```

#### Line 2
```
Position  Length  Content
1-6       6       Date of birth (YYMMDD)
7         1       Check digit (DOB)
8         1       Sex (M/F/<)
9-14      6       Date of expiry (YYMMDD)
15        1       Check digit (expiry)
16-18     3       Nationality (VNM)
19-29     11      Optional data
30        1       Composite check digit
```

#### Line 3
```
Position  Length  Content
1-30      30      Name (Surname<<Given names)
```

### Check Digit Calculation

```
Weights: 7 3 1 7 3 1 7 3 1...

Values:
0-9 = 0-9
A-Z = 10-35
< = 0

Example: "123456789"
= (1×7 + 2×3 + 3×1 + 4×7 + 5×3 + 6×1 + 7×7 + 8×3 + 9×1) mod 10
= (7 + 6 + 3 + 28 + 15 + 6 + 49 + 24 + 9) mod 10
= 147 mod 10
= 7
```

### Character Encoding

```
Special Character: <
- Used for filler
- Used for name separator
- Encoded as value 0 for check digit

Numbers: 0-9
Letters: A-Z (uppercase only)
```

## Vietnamese CCCD Specifics

### Document Number Format
```
012345678 (9 digits)
OR
C06123456 (prefix + 8 digits)
```

### Date Format
```
YYMMDD
Example: 900101 = January 1, 1990
```

### Name Format
```
SURNAME<<GIVEN<NAMES
Example: NGUYEN<<VAN<A
- Double << after surname
- Single < between given names
```

## Parsing Implementation

### Kotlin
```kotlin
data class MRZInfo(
    val documentType: String,
    val issuingState: String,
    val documentNumber: String,
    val dateOfBirth: String,
    val sex: String,
    val dateOfExpiry: String,
    val nationality: String,
    val surname: String,
    val givenNames: String
)

fun parseMRZ(line1: String, line2: String, line3: String): MRZInfo? {
    if (line1.length != 30 || line2.length != 30 || line3.length != 30) {
        return null
    }
    
    val documentType = line1.substring(0, 2)
    val issuingState = line1.substring(2, 5)
    val documentNumber = line1.substring(5, 14).replace("<", "")
    
    val dateOfBirth = line2.substring(0, 6)
    val sex = line2.substring(7, 8)
    val dateOfExpiry = line2.substring(8, 14)
    val nationality = line2.substring(15, 18)
    
    val names = line3.trim().split("<<")
    val surname = names.getOrNull(0)?.replace("<", " ") ?: ""
    val givenNames = names.getOrNull(1)?.replace("<", " ") ?: ""
    
    return MRZInfo(
        documentType = documentType,
        issuingState = issuingState,
        documentNumber = documentNumber,
        dateOfBirth = dateOfBirth,
        sex = sex,
        dateOfExpiry = dateOfExpiry,
        nationality = nationality,
        surname = surname,
        givenNames = givenNames
    )
}

fun validateCheckDigit(data: String, checkDigit: Char): Boolean {
    val weights = intArrayOf(7, 3, 1)
    var sum = 0
    
    data.forEachIndexed { index, char ->
        val value = when (char) {
            in '0'..'9' -> char - '0'
            in 'A'..'Z' -> char - 'A' + 10
            '<' -> 0
            else -> return false
        }
        sum += value * weights[index % 3]
    }
    
    return (sum % 10).toString() == checkDigit.toString()
}
```

### Swift
```swift
struct MRZInfo {
    let documentType: String
    let issuingState: String
    let documentNumber: String
    let dateOfBirth: String
    let sex: String
    let dateOfExpiry: String
    let nationality: String
    let surname: String
    let givenNames: String
}

func parseMRZ(line1: String, line2: String, line3: String) -> MRZInfo? {
    guard line1.count == 30, line2.count == 30, line3.count == 30 else {
        return nil
    }
    
    let documentType = String(line1.prefix(2))
    let issuingState = String(line1.dropFirst(2).prefix(3))
    let documentNumber = String(line1.dropFirst(5).prefix(9))
        .replacingOccurrences(of: "<", with: "")
    
    let dateOfBirth = String(line2.prefix(6))
    let sex = String(line2.dropFirst(7).prefix(1))
    let dateOfExpiry = String(line2.dropFirst(8).prefix(6))
    let nationality = String(line2.dropFirst(15).prefix(3))
    
    let names = line3.trimmingCharacters(in: .whitespaces)
        .components(separatedBy: "<<")
    let surname = names.first?.replacingOccurrences(of: "<", with: " ") ?? ""
    let givenNames = names.last?.replacingOccurrences(of: "<", with: " ") ?? ""
    
    return MRZInfo(
        documentType: documentType,
        issuingState: issuingState,
        documentNumber: documentNumber,
        dateOfBirth: dateOfBirth,
        sex: sex,
        dateOfExpiry: dateOfExpiry,
        nationality: nationality,
        surname: surname,
        givenNames: givenNames
    )
}
```

### Dart
```dart
class MRZInfo {
  final String documentType;
  final String issuingState;
  final String documentNumber;
  final String dateOfBirth;
  final String sex;
  final String dateOfExpiry;
  final String nationality;
  final String surname;
  final String givenNames;
  
  MRZInfo({
    required this.documentType,
    required this.issuingState,
    required this.documentNumber,
    required this.dateOfBirth,
    required this.sex,
    required this.dateOfExpiry,
    required this.nationality,
    required this.surname,
    required this.givenNames,
  });
}

MRZInfo? parseMRZ(String line1, String line2, String line3) {
  if (line1.length != 30 || line2.length != 30 || line3.length != 30) {
    return null;
  }
  
  final documentType = line1.substring(0, 2);
  final issuingState = line1.substring(2, 5);
  final documentNumber = line1.substring(5, 14).replaceAll('<', '');
  
  final dateOfBirth = line2.substring(0, 6);
  final sex = line2.substring(7, 8);
  final dateOfExpiry = line2.substring(8, 14);
  final nationality = line2.substring(15, 18);
  
  final names = line3.trim().split('<<');
  final surname = names.isNotEmpty ? names[0].replaceAll('<', ' ') : '';
  final givenNames = names.length > 1 ? names[1].replaceAll('<', ' ') : '';
  
  return MRZInfo(
    documentType: documentType,
    issuingState: issuingState,
    documentNumber: documentNumber,
    dateOfBirth: dateOfBirth,
    sex: sex,
    dateOfExpiry: dateOfExpiry,
    nationality: nationality,
    surname: surname,
    givenNames: givenNames,
  );
}
```

## Common Issues

### 1. OCR Errors
- **0 vs O**: Zero vs letter O
- **1 vs I**: One vs letter I
- **5 vs S**: Five vs letter S
- **< vs C**: Filler vs letter C

### 2. Name Parsing
- Multiple given names
- Names with spaces
- Special characters (removed in MRZ)

### 3. Date Validation
- Check year threshold (00-99)
- Validate month (01-12)
- Validate day (01-31)

### 4. Character Set
- Only uppercase letters
- No accents or diacritics
- No special characters except <

## References

- ICAO Doc 9303 Part 3: Machine Readable Travel Documents
- ISO/IEC 7501-1: Identification cards
