# swipe

##Abstract

This specification defines the features and syntax of Swipe, a mark-up language for non-developers to create media-rich and animated documents for touch-enabled devices.

##Status of this document

This specification describes the current snapshot of the Swipe 0.1, which is still under development and may change drastically.

##1. Introduction

Swipe is a domain-specific, declarative language for non-developers (such as designers, animators, illustrators, musicians, videographers and comic writers) to create media-rich documents (books and presentations) that contains photos, videos, vector graphics, animations, voices, musics and sound effects, which will be consumed on touch-enabled devices (such as smartphones, tablets and touch-enabled set-top-boxes). 

Since the introduction of iPhone, the capability of those mobile devices advanced significantly with faster CPU/GPU, a large amount memory and various sensors, but taking a full advantage of those capability is not easy.

While the "native programming" (such as in Objective-C, Swift, Java, and etc.) gives the best possible performance and the user experience, the development cost is very expensive, and supporting multiple devices is a nightmare.

Using a "cross-platform development environment", such as Unity, Coco3D, Corona and Flash has some advantages over native programming, but it still requires a "procedural programming", which only skilled developers are able to do. 

Building interactive applications on top of HTML browsers became possible because of HTML5, but it still has many issues. Providing a good user experience is very difficult (this is why Facebook gave up this approach), and the development cost is as expensive as native or cross-platform development, requireing skilled developers.

People often debate over those three approaches, but they often overlook one important disadvantage of those three approaches. All those approaches require "procedural programming", which can be done only by skilled developers and are very expensive, error-prone and time-consuming. 

This disadvantage makes it very difficult for those creative people to make quick prototypes and experimental works, just like an artist makes sketches with pencils and erasers. It is economically impossible for individual creators to create interactive, media-rich books and publish them. 

Swipe was born to fill this gap. It allows non-developers to create interactive and media-rich documents without any help from developers. The declarative nature of Swipe language (and the lack of "procedual programming environment") makes very easy to learn, write and read. It also makes it easy to auto-generate documents (from data) and create authoring environments. 

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
- **Color**: One of RBG(A) styles ("#RRGGBB", "#RGB", "#RRGGBBAA", "#RGBA") or, one of standard color names ("red", "black", "blue", "white", "green", "yellow", "purple", "gray", "darkGray", "lightGray", "brown", "orange", "cyan", "maganta")
- **Percent**: "NN%" relative to the parent
- **Path**: SVG-style Path String
- **URL**: relative or absolute URL

##2. Document

A **Document** is a UTF8 JSON file, which consists of a collection of **Pages**. The order of **Pages** in the collection is significant, and they will be presented to the user in the specified order. 

Here is a sample **Document** which concists of two pages:

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

- **title** (String): Title of the document, optional
- **bc** (Color): Background color, defalut is *darkGray*
- **dimension** ([Int, Int]): Dimension of the document, default is [320, 568]
- **paging** (String): Paging direction, *vertical* (default), or *leftToRight*
- **orientation** (String): Document orientation, *portrait* (default) or *landscape*
- **scene** ({Name:Scene}): Named **Scenes** dictionary
- **elements** ({Name:Element}): Named **Elements** dictionary
- **paths** ({Name:Path}): Named **Paths** dictionary
- **markdown** ({Name:Style}): Named **Markdown** style
- **voices** ({Name:VoiceInfo}): Named **Voice** style
- **pages** ([Page+]): Collection of **Pages** 

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
- **animation** (String): Animation timing, *auto* (default), *pause* or *scroll*
- **duration** (Float): Duration of the auto animation in seconds, the default is 0.2 seconds
- **repeat** (Boolean): Repeat rule of the auto animation, default is *false*
- **rewind** (Boolean): Rewind rule of the auto animation when the user leaves the page, defaul is *false*
- **scene** (String): Name of the scene, default is *
- **audio** (URL): Specifies the sound effect to be played in sync with the animation
- **speech** (SpeechInfo): Specifies the text-to-speech to be played in sync with the animation
- **vibrate** (Bool): Specifies the vibration in sync with the animation, the default is false
- **elements** ([Element+]): Collection of Elements
 
##4. Paging direction, inter-page transition and animation

The paging direction is defined by the "paging" property of the **Document**. It must be either *vertical*, *leftToRight* or *rightToLeft*, and the default is *vertical*.

The inter-page transition is defined by the "transition" property of the proceding **Page**. It should be either *scroll*, *fadeIn* or *replace*. The default is *scroll* unless the "animation" property is *scroll*. If the "animation" property is *scroll*, the default is *replace*.

### Values for the "transition" property

- *scroll*: regular scrolling behavior (default)
- *fadeIn*: The proceding **Page** will fade-in while the user drags it in.
- *replace*: The proceding **Page** will replace when the user start dragging.

The "animation" property defines the timing of animation defined on the **Page**, and it must be either *auto*, *pause* or *scroll*. If "auto" is specified, the animation will start automatically after the completion of the paging action. If *scroll* is specified, the animation will be played while the user is scrolling the page. 

### Values for the "animation" property

- *auto*: The animation on the **page** will be played after finish scrolling to this page (default)
- *pause*: The animation on the **Page** will not automatically start
- *scroll*: The animation on the **Page** will be performed while the user scrolls the page

##5. Scene

A Scene defines a set of properties and **Elements** to be shared among multile **Pages**. It also defines a background music to be played when one of those **Pages** is active.

A **Page** is always associated with a Scene, either explicity with the "scene" property or implicitly with the default scene with name "*". 

The **Page** inherits all the properties from the associated **scene**, including **Elements**. When the same property is specified both in the **Page** and the **Scene**, the value specified in the **Page** will be used. The only exception to this rule is **Elements**, which will be deep-merged (deep-inheritance). **Elements** with the *id* property will be merged, and other **Elements** will be appended (**Elements** defined in the **Scene** are always placed below **Elements** specified in the page).

Here is a **Document** with two **Pages**, where the first **Page** is associated with the default **Scene**, and the second **Page** is associated with the "alternative" **Scene**. Because each **Scene** specifies the backgroud color, those **Pages** inherite those background colors.   

```
{
    "scenes": {
        "*": { "bc":"blue" },
        "alternative": { "bc":"green" },
    },
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "scene":"alternative",
            "elements": [
                { "text":"Good Bye!" }
            ]
        }
    ]
}
```

The following example uses the "id" to identify a particular **Element** in the **Scene** and modify its "textColor" property. 

```
{
    "scenes": {
        "*": {
            "elements": [
                { "id":"hello", "text":"Hello World" },
            ]
        },
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

### Scene specific properties 
- bgm (URL): Specifies the background music to play. 

##6. Element

An **Element** is a visible entity on a **Page**. It occupies a specified rectangle area within a **Page**. An **Element** may contain child **Elements**. 

### Element properties

- **id** (String): the element identifier to identify an element in the associated **Scene**
- **element** (String): the name of the named **Element** to inherit properties from
- **x** (Float or Percent): x-position of the left-top corner of element, default is 0
- **y** (Float or Percent): y-position of the left-top corner of the element, default is 0
- **pos** ([Float/Percent, Float/Percent]): alternative way to specificy the position by the location of the anchor point
- **anchor** ([Float/Percent, Float/Percent]): anchor point, default is ["50%", "50%"]
- **w** (Float or Percent): width of the element, default is "100%"
- **h** (Float or Percent): height of the element, default is "100%"
- **bc** (Color): background color, default is *clear*, animatable
- **clip** (Boolean): Specifies clipping behavior, default is false
- **borderWidth** (Float): Width of the border, default is 0, animatable
- **borderColor** (Color): Color of the border, animatable
- **cornerRadius** (Float): Size of the corner radius, animatable
- **opacity** (Float): Opacity of the element, between 0 to 1, animatable
- **rotate** (Float): Rotation in degree around the anchor point, clockwise, defalut is 0, animatable
- **scale** (Float or [Float, Float]): Scaling factor around the anchor point, default is [1, 1], animatable
- **translate** ([Float, Float]): Translation, default is [0, 0], animatable
- **text** (String): Text to display
  - **textAlign** (String): Text alignment, *center* (default), *left* or *right*
  - **fontSize** (Float or Percent): Font size
  - **textColor** (Color): Color of the text, animatable
- **img** (URL): Image to display, animatable
- **mask** (URL): Image mask (PNG with the alpha channel)
- **sprite** (URL): Sprite to display
  - **slice** ([Int, Int]): Dimension of the sprite
  - **slot** ([Int, Int]): Slot to diplay, animatable
- **path** (Path): Path to display (SVG style), animatable
  - **lineWidth** (Float): Width of stroke, default is 0
  - **strokeColor** (Color): Color of the stroke, default is black, animatable
  - **fillColor** (Color): Fill color, default is clear, animatable
  - **strokeStart** (Float): Starting offset, default is 0, animatable
  - **strokeEnd** (Float): Ending offset, default is 1, animatable
- **video** (URL): Video to play
  - **videoStart** (Float): Starting point of the video in seconds, default is 0
  - **videoDuration** (Float): Ending point of the video in seconds
- **to** (Transition Animation): Specifies the Transitional Animation
- **loop** (Loop Animation): Specifies the Loop Animation
- **action** (String): Specifies the Action

### Named Element

Named **Elements** are a set of **Elements** defined in "elements" property of the **Document**. Any **Element** can inherit properties from one of those named **Elements** by specifying its name in the "element" property. 

The sample below uses a named **Element**, "stroke" as a template for five different **Elements** in a page. 

```
{
    "elements": {
        "smile": {
            "lineWidth":3,
            "path":"M0,0 C10,50 90,50 100,0",
            "strokeColor":"red",
        },
    },
    "pages": [
        {
            "elements": [
                { "smile":"stroke", "pos":["50%", 100] },
                { "smile":"stroke", "pos":["50%", 200], "rotate":30 },
                { "smile":"stroke", "pos":["50%", 300], "lineWidth":10 },
                { "smile":"stroke", "pos":["50%", 400], "strokeColor":"#37F" },
                { "smile":"stroke", "pos":["50%", 500], "scale":[2,1] },
            ],
        },
    ]
}
```

Just like a regular **Element**, named **Element** may have child **Elements**, and they will be deep-merged just like **Elements** in **Scene**. 

The following example shows how to use a named **Element** with child **Elements**, and override their properties using the "id" property. 

```
{
    "elements": {
        "helloWorld": {
            "w":160, "h":100,
            "elements":[
                { "id":"hello", "text":"Hello", "textAlign":"left" },
                { "id":"world", "text":"World", "textAlign":"left", "x":80 },
            ],
        },
    },
    "pages": [
        {
            "elements": [
                { "element":"helloWorld", "pos":[160, 100] },
                { "element":"helloWorld", "pos":[160, 200],
                  "elements":[
                    { "id":"hello", "textColor":"red", },
                    { "id":"world", "textColor":"blue", },
                  ]},
                { "element":"helloWorld", "pos":[160, 300],
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

The "to" property of each element specifies the animation to be performed on the element, by specifying a new value for animatable properties (such as "opacity", "rotate", "translate", "bc", "path"). 

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
If the "animation" property of the page is "auto" (which is default) like the sample above, the animation happens after the page scrolling, and the duration of the animation is determined by the "duration" property of the page (the default is 0.2 seconds). 

If the "animation" property of the page is "scroll" like the example below, the animation takes place while the user swipes the previous page up to see this page, and the "duration" property of the page will be ignored (since the user's swipe action determines the duration). 

```
{
    "pages": [
        {
            "elements": [
                { "text":"Hello World!" }
            ]
        },
        {
            "animation":"scroll",
            "elements": [
                { "text":"Hello World!", "to":{ "translate":[0, 200] } }
            ]
        }
    ]
}
```

##8. Loop Animation

The "loop" property of the element specifies the **Loop Animation** associated with the element. Unlike **Transition Animation**, it repeats the same animation multiple times specified by the *repeat* property (the default is 1). 

The **Loop Animation** must have a "style" property, and the value of this property must be one of following.

- *vibrate*: The **Element** vibrates left to right, where the "delta" property specifies the distance (the default is 10)
- *blink*: The **Element** blinks changing its opacity from 1 to 0. 
- *wiggle*: The **Element** rotates left and right, where the "delta" property specifies the angree in degree (the default is 15)
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
                { "text":"I'm wiggling!", "loop":{ "style":"wiggle", "repeat":3 } }
            ]
        }
    ]
}
```

