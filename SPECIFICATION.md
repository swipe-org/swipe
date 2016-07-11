#Swipe Language Specification

##Abstract

This specification defines the features and syntax of Swipe, a mark-up language for non-developers to create media-rich and animated documents for touch-enabled devices.

##Status of this document

This specification describes the current snapshot of the Swipe 0.1, which is still under development and may change drastically.

##1. Introduction

Swipe is a domain-specific, declarative language for non-developers (such as designers, animators, illustrators, musicians, videographers and comic writers) to create media-rich documents (books and presentations) that contains photos, videos, vector graphics, animations, voices, music and sound effects, which will be consumed on touch-enabled devices (such as smartphones, tablets and touch-enabled set-top-boxes). 

Since the introduction of iPhone, the capability of those mobile devices advanced significantly with faster CPU/GPU, a large amount memory and various sensors, but taking a full advantage of those capability is not easy.

While the "native programming" (such as in Objective-C, Swift, Java, and etc.) gives the best possible performance and the user experience, the development cost is very expensive, and supporting multiple devices is a nightmare.

Using a "cross-platform development environment", such as Unity, Coco3D, Corona and Flash has some advantages over native programming, but it still requires a "procedural programming", which only skilled developers are able to do. 

Building interactive applications on top of HTML browsers became possible because of HTML5, but it still has many issues. Providing a good user experience is very difficult (this is why Facebook gave up this approach), and the development cost is as expensive as native or cross-platform development, requiring skilled developers.

People often debate over those three approaches, but they often overlook one important disadvantage of those three approaches. All those approaches require "procedural programming", which can be done only by skilled developers and are very expensive, error-prone and time-consuming. 

This disadvantage makes it very difficult for those creative people to make quick prototypes and experimental works, just like an artist makes sketches with pencils and erasers. It is economically impossible for individual creators to create interactive, media-rich books and publish them. 

Swipe was born to fill this gap. It allows non-developers to create interactive and media-rich documents without any help from developers. The declarative nature of Swipe language (and the lack of "procedural programming environment") makes very easy to learn, write and read. It also makes it easy to auto-generate documents (from data) and create authoring environments. 

### Scope

Swipe was designed for a specific set of applications and contents. 

- Animated Comics
- Animated Children Books
- Sound Novels (Story book with pictures, BGM and sound-effects)
- Graphical Audio Books
- Photo & Video Books
- Graphical Music Albums
- Media-rich Presentations
- Video Instructions & Tutorials

Swipe is NOT 

- A replacement of ePub, which is designed for text-centric books and supports flow layout
- A general-purpose programming environment where programmers write procedural code
- A game engine
 
### Design Principles

- Domain-specific (not general purpose)
- Declarative (not a programming environment)
- JSON instead of XML
- Lightweight
- Designer friendly

### Data Types

- **String**: Regular string
- **Color**: One of RBG(A) styles ("#RRGGBB", "#RGB", "#RRGGBBAA", "#RGBA") or, one of standard color names ("red", "black", "blue", "white", "green", "yellow", "purple", "gray", "darkGray", "lightGray", "brown", "orange", "cyan", "magenta")
- **Percent**: "NN%" relative to the parent
- **Path**: SVG-style Path String
- **URL**: relative or absolute URL
- **StringId**: Regular string used as an identifier
- **LangId**: Language identifier, such as "\*", "en", "ja", "de", etc., where "\*" represents the default

##2. Document

A **Document** is a UTF8 JSON file, which consists of a collection of **Pages**. The order of **Pages** in the collection is significant, and they will be presented to the user in the specified order. 

Here is a sample **Document** which consists of two pages:

```
{
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "elements": [
                { "text":"Good Bye!" }
            ]
        }
    ]
}
```
When the user opens this document with a Swipe viewer, the user will see only the first page with text "Hello World!" in the middle of screen. The user needs to swipe up (since the vertical scrolling is the default) to see the second page.

### Document Properties

- **type** (String): This must be "net.swipe.swipe" for a Swipe document
- **version** (String): Version of the Swipe language specification used in the document
- **title** (String): Title of the document, optional
- **bc** (Color): Background color, default is *darkGray*
- **dimension** ([Int, Int]): Dimension of the document, default is [320, 568]
- **paging** (String): Paging direction, *vertical* (default), or *leftToRight*
- **orientation** (String): Document orientation, *portrait* (default) or *landscape*
- **templates** ({"elements":ElementTemplates, "pages":PageTemplates})
 - **pages** ({Name:PageTemplate}): **PageTemplate** dictionary
 - **elements** ({Name:ElementTemplate}):	 **ElementTemplate** dictionary
- **paths** ({Name:Path}): Named **Paths** dictionary
- **markdown** ({Name:Style}): Named **Markdown** style
- **voices** ({Name:VoiceInfo}): Named **Voice** style
- **pages** ([Page,...]): Collection of **Pages** 
- **resources** ([String,...]): Resource keys for on-demand resources
- **viewstate** (Bool): Indicate if we need to save&restore view state. The default is true. 
- **languages** ({"id":LangId, "title":String},...): Languages to display via the "Lang." button in the Swipe viewer.


##3. Page

**Page** consists of a collection of **Elements**. The order of **Elements** in the collection is significant, those elements will be rendered in the specified order (from bottom to top). 

Here is a **Document** with a **Page**, which has two **Elements**. 

```
{
    "pages": [
        {
            "elements": [
                { "x":50, "y":100, "w":100, "h":100, "bc":"red" },
                { "x":100, "y":150, "w":100, "h":100, "bc":"blue" },
            ]
        },
    ]
}
```

### Page Properties

- **bc** (Color): Background color, the default is *white*
- **fpt** (Int): Frame per second, the default is 60
- **transition** (String): Inter-page transition style, *scroll* (default), *fadeIn* or *replace*
- **play** (String): Play(animation) control, *auto* (default), *pause*, *always* or *scroll*
- **duration** (Float): Duration of the animation in seconds, the default is 0.2 seconds
- **repeat** (Boolean): Repeat rule of the animation, default is *false*
- **rewind** (Boolean): Rewind rule of the animation when the user leaves the page, default is *false*
- **template** (String): Name of the *PageTemplate*, default is "\*"
- **audio** (URL): Specifies the sound effect to be played in sync with the animation
- **speech** (SpeechInfo): Specifies the text-to-speech to be played in sync with the animation
- **vibrate** (Bool): Specifies the vibration in sync with the animation, the default is false
- **elements** ([Element+]): Collection of Elements
- **eyePosition** (Float): Eye position (z-height) for the perspective relative to width, default is 1.0
- **strings** ([StringId:[LangId:String]]): String resources
 
##4. Paging direction, inter-page transition and animation

The paging direction is defined by the "paging" property of the **Document**. It must be either *vertical*, *leftToRight* or *rightToLeft*, and the default is *vertical*.

The inter-page transition is defined by the "transition" property of the preceding **Page**. It should be either *scroll*, *fadeIn* or *replace*. The default is *scroll* unless the "play" property is *scroll*. If the "play" property is *scroll*, the default is *replace*.

### Values for the "transition" property

- *scroll*: regular scrolling behavior (default)
- *fadeIn*: The preceding **Page** will fade-in while the user drags it in.
- *replace*: The preceding **Page** will replace when the user start dragging.

The "play" property defines the timing of play/animation defined on the **Page**, and it must be either *auto*, *pause*, *always* or *scroll*. If "auto" is specified, the animation will start automatically after the completion of the forward paging action. If "always" is specified, the animation will start after the completion of the backward paging action as well. If *scroll* is specified, the animation will be played while the user is scrolling the page. 

### Values for the "play" property

- *auto*: The animation on the **page** will be played after forward scrolling to this page (default)
- *pause*: The animation on the **Page** will not automatically start
- *always*: The animation on the **Page** will be played after scrolling to this page
- *scroll*: The animation on the **Page** will be performed while the user scrolls the page

##5. Page Template

A **PageTemplate** defines a set of properties and **Elements** to be shared among multiple **Pages**. It also defines a background music to be played when one of those **Pages** is active.

A **Page** is always associated with a **PageTemplate**, either explicitly with the "template" property or implicitly with the default **PageTemplate** with name "*".

The **Page** inherits all the properties from the associated **PageTemplate**, including **Elements**. When the same property is specified both in the **Page** and the **PageTemplate**, the value specified in the **Page** will be used. The only exception to this rule is **Elements**, which will be deep-merged (deep-inheritance). **Elements** with the *id* property will be merged, and other **Elements** will be appended (**Elements** defined in the **PageTemplate** are always placed below **Elements** specified in the page).

Here is a **Document** with two **Pages**, where the first **Page** is associated with the default **PageTemplate**, and the second **Page** is associated with the "alternative" **PageTemplate**. Because each **PageTemplate** specifies the background color, those **Pages** inherit those background colors.   

```
{
    "templates": {
        "pages": {
            "*": { "bc":"blue" },
            "alternative": { "bc":"green" },
        }
    },
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "template":"alternative",
            "elements": [
                { "text":"Good Bye!" }
            ]
        }
    ]
}
```

The following example uses the "id" to identify a particular **Element** in the **PageTemplate** and modify its "textColor" property.

```
{
    "templates": {
        "pages": {
            "*": {
                "elements": [
                    { "id":"hello", "text":"Hello World" },
                ]
            }
        }
    },
    "pages": [
        {
            "elements": [
                { "id":"hello", "textColor":"red" }
            ]
        },
        {
            "elements": [
                { "id":"hello", "textColor":"green" }
            ]
        },
    ]
}
```

### PageTemplate specific properties
- bgm (URL): Specifies the background music to play.

##6. Element

An **Element** is a visible entity on a **Page**. It occupies a specified rectangle area within a **Page**. An **Element** may contain child **Elements**. 

### Element properties

- **id** (String): the element identifier in the associated **ElementTemplate** at the same nesting level
- **template** (String): the name of the **ElementTemplate** to inherit properties from
- **x** (Float or Percent): x-position of the left-top corner of element, default is 0
- **y** (Float or Percent): y-position of the left-top corner of the element, default is 0
- **pos** ([Float/Percent, Float/Percent]): alternative way to specify the position by the location of the anchor point
- **anchor** ([Float/Percent, Float/Percent]): anchor point, default is ["50%", "50%"]
- **w** (Float, Percent or "fill"): width of the element, default is "100%".
- **h** (Float, Percent or "fill"): height of the element, default is "100%"
- **bc** (Color): background color, default is *clear*, animatable
- **clip** (Boolean): Specifies clipping behavior, default is false
- **borderWidth** (Float): Width of the border, default is 0, animatable
- **borderColor** (Color): Color of the border, animatable
- **cornerRadius** (Float): Size of the corner radius, animatable
- **opacity** (Float): Opacity of the element, between 0 to 1, animatable
- **rotate** (Float or Float[3]): Rotation in degree around the anchor point, clockwise, default is 0, animatable. 
- **scale** (Float or [Float, Float]): Scaling factor around the anchor point, default is [1, 1], animatable
- **translate** ([Float, Float]): Translation, default is [0, 0], animatable
- **text** (String, [langId:String] or ["ref":StringId]): Text to display
  - **textAlign** (String): Text alignment, *center* (default), *left* or *right*
  - **fontSize** (Float or Percent): Font size
  - **fontName** (String or [String]): Font name or names (the first name existing in the system is used)
  - **textColor** (Color): Color of the text, animatable
- **img** (URL): Image to display, animatable
- **mask** (URL): Image mask (PNG with the alpha channel)
- **sprite** (URL): Sprite to display
  - **slice** ([Int, Int]): Dimension of the sprite
  - **slot** ([Int, Int]): Slot to display, animatable
- **path** (Path): Path to display (SVG style), animatable
  - **lineWidth** (Float): Width of stroke, default is 0
  - **strokeColor** (Color): Color of the stroke, default is black, animatable
  - **fillColor** (Color): Fill color, default is clear, animatable
  - **strokeStart** (Float): Starting offset, default is 0, animatable
  - **strokeEnd** (Float): Ending offset, default is 1, animatable
- **video** or **radio** (URL): Video/Radio to play
  - **videoStart** (Float): Starting point of the video in seconds, default is 0
  - **videoDuration** (Float): Ending point of the video in seconds
- **stream** (Bool): Specifies if the resource specified with the video tag is stream or not, default is false
- **to** (Transition Animation): Specifies the Transitional Animation
- **loop** (Loop Animation): Specifies the Loop Animation
- **tiling** (Bool): Specifies the tiling (to be used with *shift* loop animation)
- **action** (String): Specifies the Action
- **repeat** (Bool): Repeat rule for the element. The default is false.

### Element Template

**ElementTemplates** are a set of **Elements** defined in "elements" property of the **Document**. Any **Element** can inherit properties from one of those **ElementTemplates** by specifying its name in the "template" property.

The sample below uses a **ElementTemplate**, "smile" as a template for five different **Elements** in a page.

```
{
    "templates": {
        "elements": {
            "smile": {
                "lineWidth":3,
                "path":"M0,0 C10,50 90,50 100,0",
                "strokeColor":"red",
            }
        }
    },
    "pages": [
        {
            "elements": [
                { "template":"smile", "pos":["50%", 100] },
                { "template":"smile", "pos":["50%", 200], "rotate":30 },
                { "template":"smile", "pos":["50%", 300], "lineWidth":10 },
                { "template":"smile", "pos":["50%", 400], "strokeColor":"#37F" },
                { "template":"smile", "pos":["50%", 500], "scale":[2,1] },
            ],
        },
    ]
}
```

Just like a regular **Element**, **ElementTemplate** may have child **Elements**, and they will be deep-merged just like **Elements** in **PageTemplate**.

The following example shows how to use a **ElementTemplate** with child **Elements**, and override their properties using the "id" property.

```
{
    "templates": {
        "elements": {
            "helloWorld": {
                "w":160, "h":100,
                "elements":[
                    { "id":"hello", "text":"Hello", "textAlign":"left" },
                    { "id":"world", "text":"World", "textAlign":"left", "x":80 },
                ],
            },
        }
    },
    "pages": [
        {
            "elements": [
                { "template":"helloWorld", "pos":[160, 100] },
                { "template":"helloWorld", "pos":[160, 200],
                  "elements":[
                    { "id":"hello", "textColor":"red", },
                    { "id":"world", "textColor":"blue", },
                  ]},
                { "template":"helloWorld", "pos":[160, 300],
                  "elements":[
                    { "id":"world", "text":"Swipe!" },
                  ]},
            ],
        },
    ]
}
```

##7. Transition Animation

The **Transition Animation** specifies a set of animations to play right after or during the page transition (depending on the "transition" property of the page).

The "to" property of each element specifies the animation to be performed on the element, by specifying a new value for animatable properties (such as "opacity", "rotate", "translate", "bc", "path", "pos", "mode"). 

The "timing" property specifies the timing of animation with two floating values, start and end (must be between 0.0 and 1.0). The default is [0.0, 1.0].

Following example animates the text "I'm animatable!" down when the second page appears on the screen. 

```
{
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "elements": [
                { "text":"I'm animatable!", "to":{ "translate":[0, 200] } }
            ]
        }
    ]
}
```
If the "play" property of the page is "auto" (which is default) like the sample above, the animation happens after the page scrolling, and the duration of the animation is determined by the "duration" property of the page (the default is 0.2 seconds). 

If the "play" property of the page is "scroll" like the example below, the animation takes place while the user swipes the previous page up to see this page, and the "duration" property of the page will be ignored (since the user's swipe action determines the duration). 

```
{
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "play":"scroll",
            "elements": [
                { "text":"Hello World!", "to":{ "translate":[0, 200] } }
            ]
        }
    ]
}
```

##8. Loop Animation

The "loop" property of the element specifies the **Loop Animation** associated with the element. Unlike **Transition Animation**, it repeats the same animation multiple times specified by the *count* property (the default is 1). 

The **Loop Animation** must have a "style" property, and the value of this property must be one of following.

- *vibrate*: The **Element** vibrates left to right, where the "delta" property specifies the distance (the default is 10)
- *blink*: The **Element** blinks changing its opacity from 1 to 0. 
- *wiggle*: The **Element** rotates left and right, where the "delta" property specifies the angle in degree (the default is 15)
- *spin*: The **Element** spins, where the "clockwise" property (boolean) specifies the direction, the default is true. 
- *shift*: The **Element** shift to the specified direction where the "direction" property specifies the direction ("n", "s", "e" or "w", the default is "s"). Use it with the "tiling" property.
- *path*: The **Element** performs path animation, where the "path" property specifies a collection of **Paths**. 
- *sprite*: The **Element** performs a sprite animation. 
 
Following example wiggles the text "I'm wiggling!" three times when the second page appears on the screen. 

```
{
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "elements": [
                { "text":"I'm wiggling!", "loop":{ "style":"wiggle", "count":3 } }
            ]
        }
    ]
}
```

##9. Multilingual Strings

The "strings" property of the page specifies strings in multiple languages.  The format is:

```
	"strings": {StringId: {LangId:String, ...}}
```

"text" elements on the page can specify the string via the "ref" property which has the format:
```
	"text":{"ref":StringId}
```

Following example displays "good day" and "good evening" unless the locale is "de"; then "Guten Tag" and "guten Abend" are displayed. 

```
{
    "pages":[
        {
            "strings": { 
            	"good day": {"*":"good day", "de": "Guten Tag"},
            	"good evening": {"*":"good evening", "de": "guten Abend"},
            },
            	
            "elements":[
                { "text":{"ref":"good day"}, "h":"20%", "pos":["50%", "12%"]},
                { "text":{"ref":"good evening"}, "h":"20%", "pos":["50%", "34%"]},
            ],
        }
    ]
}
```

Alternatively, the "text" element can directly specify the strings for each language directly using the following format:
```
	"text":{ LangId:String, ...}
```

Following example displays "good morning" and "good afternoon" unless the locale is "de"; then "guten Morgen" and "guten Nachmittag" are displayed. 
```
{
    "pages":[
        {
            "elements":[
                { "text":{"*":"good morning", "de": "guten Morgen"}, "h":"20%", "pos":["50%", "12%"]},
                { "text":{"*":"good afternoon", "de": "guten Nachmittag"}, "h":"20%", "pos":["50%", "34%"]},
            ]
        }
    ]
}
```

To enable language selection in the Swipe viewer via the "Lang." button, use the **Document** property **languages** to list the available languages using the following format:

```
	"languages":[{"id":LangId, "title":String},...]
```

Example:
```
{ 
    "languages":[
        {"id": "en", "title": "English"},
        {"id": "de", "title": "German"},
    ],
    "pages":[
        {
            "elements":[
                { "text":{"*":"good morning", "de": "guten Morgen"}, "h":"20%", "pos":["50%", "12%"]},
                { "text":{"*":"good afternoon", "de": "guten Nachmittag"}, "h":"20%", "pos":["50%", "34%"]},
            ],
        }
    ]
}

```